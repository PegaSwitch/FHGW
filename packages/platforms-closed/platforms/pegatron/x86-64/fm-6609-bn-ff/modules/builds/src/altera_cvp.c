/*
 * Written by: Altera Corporation <support@altera.com>
 *
 * Copyright (C) 2012 - 2015 Altera Corporation. All Rights Reserved.
 *
 * This file is provided under a dual BSD/GPLv2 license.  When using or
 * redistributing this file, you may do so under either license. The text of
 * the BSD license is provided below.
 *
 * BSD License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * 3. The name of the author may not be used to endorse or promote products
 * derived from this software without specific prior written permission. 
 *
 * Alternatively, provided that this notice is retained in full, this software
 * may be distributed under the terms of the GNU General Public License ("GPL")
 * version 2, in which case the provisions of the GPL apply INSTEAD OF those
 * given above. A copy of the GPL may be found in the file GPLv2.txt provided
 * with this distribution in the same directory as this file.
 *
 * THIS SOFTWARE IS PROVIDED BY ALTERA CORPORATION "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

/* Uncomment the following line to see additional debug messages */
/*#define DEBUG	*/

#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/sched.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/device.h> /* dev_err(), etc. */
#include <linux/pci.h>
#include <linux/init.h>
#include <linux/cdev.h>
#include <linux/uaccess.h> /* copy_to/from_user */
#include <linux/slab.h>  /* kmalloc */
#include <linux/delay.h> /* msleep */

#include "altera_cvp.h"

/* PCIe Vendor & Device IDs are parameters passed to the module when it's loaded */
static unsigned short vid = 0x1172; /* default to Altera's Vendor ID */
static unsigned short did = 0x0000; /* default to PCIe Reference Design Device ID */
module_param(vid, ushort, S_IRUGO);
module_param(did, ushort, S_IRUGO);

struct altera_cvp_dev cvp_dev; /* contents initialized in altera_cvp_init() */
static unsigned int altera_cvp_major; /* major number to use */

static struct class* cvp_drv_class;
/* Global to track credits sent/consumed to throttle transmits */
u32 credits_sent = 0;
u32 device_credits=0;
u8 last_credit_byte = 0;
u8* send_buf = 0;
static spinlock_t my_lock = __SPIN_LOCK_UNLOCKED(my_lock);

/* CvP helper functions */

static int altera_cvp_get_offset_and_mask(int bit, int *byte_offset, u8 *mask)
{
	switch (bit) {
		case DATA_ENCRYPTED:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_STATUS;
			*mask = MASK_DATA_ENCRYPTED;
			break;
		case DATA_COMPRESSED:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_STATUS;
			*mask = MASK_DATA_COMPRESSED;
			break;
		case CVP_CONFIG_READY:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_STATUS;
			*mask = MASK_CVP_CONFIG_READY;
			break;
		case CVP_CONFIG_ERROR:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_STATUS;
			*mask = MASK_CVP_CONFIG_ERROR;
			break;
		case CVP_EN:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_STATUS;
			*mask = MASK_CVP_EN;
			break;
		case USER_MODE:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_STATUS;
			*mask =  MASK_USER_MODE;
			break;
		case PLD_CLK_IN_USE:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_STATUS + 1;
			*mask = MASK_PLD_CLK_IN_USE;
			break;
		case CVP_CONFIG_SUCCESS:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_STATUS +1;
			*mask = MASK_CVP_CONFIG_SUCCESS;
			break;
		case CVP_MODE:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_MODE_CTRL;
			*mask = MASK_CVP_MODE;
			break;
		case PLD_DISABLE:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_MODE_CTRL;
			*mask = MASK_PLD_DISABLE;
			break;
		case CVP_CONFIG:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_PROG_CTRL;
			*mask = MASK_CVP_CONFIG;
			break;
		case START_XFER:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_CVP_PROG_CTRL;
			*mask = MASK_START_XFER;
			break;
		case CVP_CFG_ERR_LATCH:
			*byte_offset = cvp_dev.vsec_offset + OFFSET_UNC_IE_STATUS;
			*mask = MASK_CVP_CFG_ERR_LATCH;
			break;
		default:
			return -EINVAL;
	}
	return 0;
}

static int altera_cvp_read_bit(int bit, u8 *value)
{
	int byte_offset;
	u8 byte_val, byte_mask;
	if (altera_cvp_get_offset_and_mask(bit, &byte_offset, &byte_mask))
		return -EINVAL;
	if (pci_read_config_byte(cvp_dev.pci_dev, byte_offset, &byte_val))
		return -EAGAIN;
	*value = (byte_val & byte_mask) ? 1 : 0;
	return 0;
}

static int altera_cvp_write_bit(int bit, u8 value)
{
	int byte_offset;
	u8 byte_val, byte_mask;

	switch (bit) {
		case CVP_MODE:
		case PLD_DISABLE:
		case CVP_CONFIG:
		case START_XFER:
		case CVP_CFG_ERR_LATCH:
			altera_cvp_get_offset_and_mask(bit, &byte_offset, &byte_mask);
			pci_read_config_byte(cvp_dev.pci_dev, byte_offset, &byte_val);
			byte_val = value ? (byte_val | byte_mask) : (byte_val & ~byte_mask);
			pci_write_config_byte(cvp_dev.pci_dev, byte_offset, byte_val);
			return 0;
		default:
			return -EINVAL; /* only the bits above are writeable */
	}
} 

static int wait_for_credit(void) noinline; 
static int wait_for_credit(void)
{
	u8 byte_val;
	u8 cfg_error=1;
	u8 delta_credit=0;
	u8 first_pass = 1;
#ifdef DEBUG
	u8 message_logged = 0;
#endif
	u32 count = 0;

	do{

		/*CK fix*/
		pci_read_config_byte(cvp_dev.pci_dev, cvp_dev.vsec_offset + OFFSET_CVP_CREDITS, &byte_val);         
		delta_credit = (byte_val - last_credit_byte) & 0xff;
		device_credits = device_credits + (u32)delta_credit;
		last_credit_byte = byte_val;

		if(first_pass){
			first_pass = 0;
		}
		else{
#ifdef DEBUG
			if(message_logged == 0){
				dev_dbg(&cvp_dev.pci_dev->dev, "Waiting for Credit -- host:device 0x%x : 0x%x.\n",
					credits_sent, device_credits);
				message_logged = 1;
			}
#endif
			udelay(1);
		}
		altera_cvp_read_bit(CVP_CONFIG_ERROR, &cfg_error);
		if (cfg_error) {
			dev_err(&cvp_dev.pci_dev->dev, "CE Bit error "
				"credits (host:device)  %d : %d\n",
		        	credits_sent, device_credits);
			return -EAGAIN;
		}
		count++;
		if(count > 20000){
			dev_err(&cvp_dev.pci_dev -> dev, "Timed out waiting for credit\n");
			pci_read_config_byte(cvp_dev.pci_dev, cvp_dev.vsec_offset + OFFSET_CVP_CREDITS, &byte_val);         
			dev_err(&cvp_dev.pci_dev -> dev, "Credit Register = 0x%x, Device Credits = 0x%X, Host Credits = 0x%x\n",
				byte_val, device_credits, credits_sent);
			return -ETIMEDOUT;
		}
	} while (credits_sent >= device_credits);
	return 0;
}

static int altera_cvp_send_data(void *data, unsigned long num_bytes)
{
	u8 cfg_error = 1;

	if(wait_for_credit() != 0) {
		return -EAGAIN;
	}

	get_cpu();
	spin_lock(&my_lock);

	iowrite32_rep(cvp_dev.wr_addr, data, num_bytes/4);

	spin_unlock(&my_lock);
	put_cpu();

	credits_sent++;

	altera_cvp_read_bit(CVP_CONFIG_ERROR, &cfg_error);
	if (cfg_error) {
		dev_err(&cvp_dev.pci_dev->dev, "CE Bit error %d "
			"credits (host:device)  %d : %d\n",\
                        cfg_error, credits_sent, device_credits);
	}
	if(cfg_error)
		return -EAGAIN;

	dev_dbg(&cvp_dev.pci_dev->dev, "A total of %ld 32-bit words were "
		"sent to the FPGA\n", num_bytes/4);

	return 0;
}

/* Polls the requested bit until it has the specified value (or until timeout) */
/* Returns 0 once the bit has that value, error code on timeout */
static int altera_cvp_wait_for_bit(int bit, u8 value, u32 n_us, char *bit_name)
{
	int rc = 0;
	u8 bit_val;
	u32 n_wait_loops = (n_us > (US_PER_JIFFY * MIN_WAIT)) ?
		(n_us + (US_PER_JIFFY * MIN_WAIT) - 1) / (US_PER_JIFFY * MIN_WAIT) : 1;

	DECLARE_WAIT_QUEUE_HEAD(cvp_wq);

	altera_cvp_read_bit(bit, &bit_val);

	while ((bit_val != value) && (n_wait_loops != 0)) {
		wait_event_timeout(cvp_wq, 0, MIN_WAIT);
		altera_cvp_read_bit(bit, &bit_val);
		--n_wait_loops;
	}

	if (bit_val != value) {
		dev_info(&cvp_dev.pci_dev->dev, "Timed out while polling %s bit %d for value %d\n",
			 bit_name, bit, value);
		rc = -EAGAIN;
	}

	return rc;
}

static int altera_cvp_setup(void)
{
	u8 cfg_error;

	/* Be sure all running credit counters are initialized/reset properly. */
	credits_sent = 0;
	device_credits=0;
	last_credit_byte = 0;

	altera_cvp_write_bit(PLD_DISABLE, 1);
	altera_cvp_write_bit(CVP_MODE, 1);
	/*altera_cvp_switch_clk();  allow CB to sense if system reset is issued : shouldn't be needed in Stratix10 */
	altera_cvp_write_bit(CVP_CONFIG, 0); /* request CB to begin CvP transfer */
	/* Ensure that any previous transactions are cancelled. */
	altera_cvp_write_bit(START_XFER, 0);
	if (altera_cvp_wait_for_bit(CVP_CONFIG_READY, 0, 1000000, "CVP_CONFIG_READY")) /* wait until previous are cleared */
		return -EAGAIN;
	altera_cvp_write_bit(CVP_CONFIG, 1); /* Tell the FPGA that I want to initiate CvP transactions */
	if (altera_cvp_wait_for_bit(CVP_CONFIG_READY, 1, 1000000, "CVP_CONFIG_READY")) /* wait until CB is ready */
		return -EAGAIN;
	if (altera_cvp_wait_for_bit(USER_MODE, 0, 1000000, "USER_MODE"))
		return -EAGAIN;
	if (altera_cvp_wait_for_bit(PLD_CLK_IN_USE, 0, 1000000, "PLD_CLK_IN_USE"))
		return -EAGAIN;
	/* Check success and failure bits for sanity */
	altera_cvp_read_bit(CVP_CONFIG_ERROR, &cfg_error);
	if (cfg_error) {
		dev_err(&cvp_dev.pci_dev->dev, "Device failure, config error before start!\n");
		return -EAGAIN;
	}

	/*altera_cvp_switch_clk(); Shouldn't be necessary in Stratix10.*/
	altera_cvp_write_bit(START_XFER, 1);
	/*altera_cvp_set_data_type(); Shouldn't be necessary in Stratix10.*/
	dev_info(&cvp_dev.pci_dev->dev, "Now starting CvP...\n");

        send_buf = kmalloc(SEND_BUF_INITIAL_SIZE, GFP_KERNEL);

	return 0; /* success */
}

static int altera_cvp_teardown(void)
{
	u8 cfg_error;
	u8 byte_val;

	if(send_buf) {
		kfree(send_buf);
		send_buf = 0;
	}

	/* if necessary, flush remainder buffer */
	if (cvp_dev.remain_size > 0) {
		u32 last_word = 0;
		memcpy(&last_word, cvp_dev.remain, cvp_dev.remain_size);
		altera_cvp_send_data(&last_word, cvp_dev.remain_size);
	}

	altera_cvp_read_bit(CVP_CONFIG_ERROR, &cfg_error);
	if (cfg_error == 1) {
		dev_err(&cvp_dev.pci_dev->dev, "Configuration error detected, "
			"CvP has failed\n");
	}

        /* Dump out the value of the credits.  */
	pci_read_config_byte(cvp_dev.pci_dev, cvp_dev.vsec_offset + OFFSET_CVP_CREDITS, &byte_val);
        
	dev_info(&cvp_dev.pci_dev->dev, "Device Final Credits 0x%x.\n", device_credits);
	dev_info(&cvp_dev.pci_dev->dev, "Host Final Sent 0x%x.\n", credits_sent);

	altera_cvp_write_bit(START_XFER, 0);
	altera_cvp_write_bit(CVP_CONFIG, 0); /* request CB to end CvP transfer */
	/*altera_cvp_switch_clk(); Not necessary in Stratix10.*/

	if (altera_cvp_wait_for_bit(CVP_CONFIG_READY, 0, 1000000, "CVP_CONFIG_READY")) /* wait until CB is ready */ 
		goto error_path;

	altera_cvp_read_bit(CVP_CONFIG_ERROR, &cfg_error);
	if (cfg_error == 1) {
		dev_err(&cvp_dev.pci_dev->dev, "Configuration error detected, "
			"CvP has failed\n");
		goto error_path;
	}

	if (altera_cvp_wait_for_bit(USER_MODE, 1, 350000, "USER_MODE"))
		goto error_path;

	altera_cvp_write_bit(CVP_MODE, 0);
	altera_cvp_write_bit(PLD_DISABLE, 0); /* Changed from HIP_CLK_SEL on Stratix10.*/

	/* wait for application layer to be ready */
	if (altera_cvp_wait_for_bit(PLD_CLK_IN_USE, 1, 350000, "PLD_CLK_IN_USE"))
		return -ETIMEDOUT;

	dev_info(&cvp_dev.pci_dev->dev, "CvP successful, application "
					"layer now ready\n");
	return 0; /* success */

error_path:
	altera_cvp_write_bit(CVP_MODE, 0);
	altera_cvp_write_bit(PLD_DISABLE, 0); /* Changed from HIP_CLK_SEL on Stratix10.*/
	return -EAGAIN;
}

/* Open and close */

int altera_cvp_open(struct inode *inode, struct file *filp)
{
	/* Make sure we actually created the device before using it */
	if (!cvp_dev.pci_dev || !pci_is_enabled(cvp_dev.pci_dev)) {
		pr_err("Device not enabled. Exiting...\n");
		return -ENODEV;
	}

	/* enforce single-open */
	if (!atomic_dec_and_test(&cvp_dev.is_available)) {
		atomic_inc(&cvp_dev.is_available);
		return -EBUSY;
	}

	if ((filp->f_flags & O_ACCMODE) != O_RDONLY) {
		u8 cvp_enabled = 0;
		if (altera_cvp_read_bit(CVP_EN, &cvp_enabled))
			return -EAGAIN;
		if (cvp_enabled) {
			return altera_cvp_setup();
		} else {
			dev_err(&cvp_dev.pci_dev->dev, "CvP is not enabled in "
							"the design on this "
							"FPGA\n");
			return -EOPNOTSUPP;
		}
	}
	return 0; /* success */
}

int altera_cvp_release(struct inode *inode, struct file *filp)
{
	atomic_inc(&cvp_dev.is_available); /* release the device */
	if ((filp->f_flags & O_ACCMODE) != O_RDONLY) {
		return altera_cvp_teardown();
	}
	return 0; /* success */
}


/* Read and write */

ssize_t altera_cvp_read(struct file *filp, char __user *buf, size_t count, loff_t *f_pos)
{
	int dev_size = NUM_VSEC_REGS * BYTES_IN_REG;
	int i, byte_offset;
	u8 *out_buf;
	ssize_t ret_val; /* number of bytes successfully read */

	if (*f_pos >= dev_size)
		return 0; /* we're at EOF already */
	if (*f_pos + count > dev_size)
		count = dev_size - *f_pos; /* we can only read until EOF */

	out_buf = kmalloc(count, GFP_KERNEL);

	/* Dump of VSEC register space to binary file and to syslog. */
	dev_info(&cvp_dev.pci_dev->dev, "VSEC register space dump, byte-by-byte\n" );
	dev_info(&cvp_dev.pci_dev->dev, "Offset: Value\n" );

	for (i = 0; i < count; i++) {
		byte_offset = cvp_dev.vsec_offset + *f_pos + i;
		pci_read_config_byte(cvp_dev.pci_dev, byte_offset, &out_buf[i]);
		dev_info(&cvp_dev.pci_dev->dev, "0x%x: 0x%02x\n", (byte_offset-0xb80), out_buf[i]); 
	}

	if (copy_to_user(buf, out_buf, count)) {
		ret_val = -EFAULT;
	} else {
		*f_pos += count;
		ret_val = count;
	}

	kfree(out_buf);
	return ret_val;
}

ssize_t altera_cvp_write(struct file * filp, const char __user *buf, size_t count, loff_t *f_pos)
{
	ssize_t ret_val; /* number of bytes successfully transferred */
	u8 *send_ptr;
	size_t send_buf_size;
	size_t bytes_to_send;
	size_t bytes_remaining;

	send_buf_size = count + cvp_dev.remain_size;
	if(ksize(send_buf) < send_buf_size){
		kfree(send_buf);
		send_buf = kmalloc(send_buf_size, GFP_KERNEL);
	}

	if (cvp_dev.remain_size > 0)
		memcpy(send_buf, cvp_dev.remain, cvp_dev.remain_size);

	if (copy_from_user(send_buf + cvp_dev.remain_size, buf, count)) {
		ret_val = -EFAULT;
		goto exit;
	}

	/* calculate new remainder */
	cvp_dev.remain_size = send_buf_size % 4;

	/* save bytes in new remainder in cvp_dev */
	if (cvp_dev.remain_size > 0)
		memcpy(cvp_dev.remain,
			send_buf + (send_buf_size - cvp_dev.remain_size),
			cvp_dev.remain_size);

	// Chunk data to max of 4096
	bytes_remaining = send_buf_size;
	send_ptr = send_buf;
	while(bytes_remaining){
		if(bytes_remaining < 4096){
			bytes_to_send = bytes_remaining;
		}
		else{
			bytes_to_send = 4096;
		}
		if (altera_cvp_send_data((void *)send_ptr, bytes_to_send)) {
			ret_val = -EAGAIN;
			goto exit;
		}
		bytes_remaining -= bytes_to_send;
		send_ptr += bytes_to_send;
	}

	*f_pos += count;
	ret_val = count;
exit:
	return ret_val;
}

static long altera_cvp_ioctl(struct file *filp, unsigned int cmd, unsigned long arg){
	switch(cmd){
		default:
			dev_info(&cvp_dev.pci_dev->dev, "Reached ioctl() call.\n");
			return -ENOTTY;
	}
}

struct file_operations altera_cvp_fops = {
	.owner =   THIS_MODULE,
	.llseek =  no_llseek,
	.read =    altera_cvp_read,
	.write =   altera_cvp_write,
	.open =    altera_cvp_open,
	.release = altera_cvp_release,
        .unlocked_ioctl = altera_cvp_ioctl,
};

/* PCI functions */

static int altera_cvp_probe(struct pci_dev *dev, const struct pci_device_id *id)
{
	int offset, rc = 0;
	unsigned long flags = 0;
	u32 val;

	if((dev->vendor == vid) && (dev->device == did)) {
		rc = pci_enable_device(dev);
		if (rc) {
			dev_err(&dev->dev, "pci_enable device() failed\n");
			return rc;
		}
		dev_info(&dev->dev, "Found and enabled PCI device with "
					"VID 0x%04X, DID 0x%04X\n", vid, did);

		offset = pci_find_next_ext_capability(dev, 0, PCI_EXT_CAP_ID_VNDR);
		if (!offset) {
			dev_err(&dev->dev, "Can't find Vendor Specific Offset.\n");
			return -ENODEV;

		}
		cvp_dev.vsec_offset = offset;
		dev_info(&dev->dev, "Found Vendor Specific data at 0x%X\n", offset);

		pci_read_config_dword(dev, offset + 0x0, &val);
		dev_dbg(&dev->dev, "Offset 0 = 0x%08X\n", val);
		dev_info(&dev->dev, "Vendor Specific Extended Capability ID = 0x%08lX\n",
			FIELD_GET(ALT_VSC_EXT_CAP_ID, val));
		dev_dbg(&dev->dev, "Vendor Specific Version = 0x%08lX\n",
			FIELD_GET(ALT_VSC_VERSION, val));
		dev_dbg(&dev->dev, "Vendor Specific Next Cap Offset = 0x%08lX\n",
			FIELD_GET(ALT_VSC_NCO, val));
		pci_read_config_dword(dev, offset + 0x4, &val);
		dev_dbg(&dev->dev, "Offset 4 = 0x%08X\n", val);
		dev_info(&dev->dev, "VSEC ID = 0x%08lX\n",
			FIELD_GET(ALT_VSH_VSEC_ID, val));
		dev_info(&dev->dev, "VSEC Revision = 0x%08lX\n",
			FIELD_GET(ALT_VSH_VSEC_REV, val));
		dev_info(&dev->dev, "VSEC Length = 0x%08lX\n",
			FIELD_GET(ALT_VSH_VSEC_LEN, val));

		rc = pci_request_regions(dev, ALTERA_CVP_DRIVER_NAME);
		if (rc) {
			dev_err(&dev->dev, "pci_request_regions() failed\n");
			return rc;
		}
		flags = pci_resource_flags(dev, 0);
		dev_info(&dev->dev, "Device flags: 0x%08X, IO: %s, MEM: %s, MEM_CACHED: %s",
			(unsigned int)flags,
			((flags & IORESOURCE_IO) ? "true" : "false"),
			((flags & IORESOURCE_MEM) ? "true" : "false"),
			((flags & IORESOURCE_CACHEABLE) ? "true" : "false"));
		dev_info(&dev->dev, "BAR 0 Region Size: %llu", pci_resource_len(dev,0));

		cvp_dev.wr_addr = ioremap_nocache(pci_resource_start(dev, 0), pci_resource_len(dev, 0));

		cvp_dev.pci_dev = dev; /* store pointer for PCI API calls */
		return 0;
	} else {
		dev_err(&dev->dev, "This PCI device does not match "
					"VID 0x%04X, DID 0x%04X\n", vid, did);
		return -ENODEV;
	}
}

static void altera_cvp_remove(struct pci_dev *dev)
{
	iounmap(cvp_dev.wr_addr);
	pci_disable_device(dev);
	pci_release_regions(dev);
	cvp_dev.pci_dev = 0;
}

/* PCIe HIP on FPGA can have any combination of IDs based on design settings */
static struct pci_device_id pci_ids[] = {
	{ PCI_DEVICE(PCI_ANY_ID, PCI_ANY_ID), },
	{ 0, }
};
MODULE_DEVICE_TABLE(pci, pci_ids);

static struct pci_driver cvp_driver = {
	.name = ALTERA_CVP_DRIVER_NAME,
	.id_table = pci_ids,
	.probe = altera_cvp_probe,
	.remove = altera_cvp_remove,
};

/* Module functions */

static int __init altera_cvp_init(void)
{
	int rc = 0;
	dev_t dev;

	rc = alloc_chrdev_region(&dev, 0, 1, ALTERA_CVP_DEVFILE);
	if (rc) {
		printk(KERN_ERR "%s: Allocation of char device numbers "
					"failed\n", ALTERA_CVP_DRIVER_NAME);
		goto exit;
	}

	cvp_dev.dev = dev; /* store major and minor numbers for char device */
	altera_cvp_major = MAJOR(dev);

	rc = pci_register_driver(&cvp_driver);
	if (rc) {
		printk(KERN_ERR "%s: PCI driver registration failed\n",
			ALTERA_CVP_DRIVER_NAME);
		unregister_chrdev_region(MKDEV(altera_cvp_major, 0), 1);
		goto exit;
	}

	cdev_init(&cvp_dev.cdev, &altera_cvp_fops);
	cvp_dev.cdev.owner = THIS_MODULE;
	rc = cdev_add(&cvp_dev.cdev, dev, 1);
	if (rc) {
		printk(KERN_ERR "%s: Unable to add char device to the "
					"system\n", ALTERA_CVP_DRIVER_NAME);
		pci_unregister_driver(&cvp_driver);
		goto exit;
	}

    if ((cvp_drv_class = class_create(THIS_MODULE, "cvp_class")) == NULL) {
		printk(KERN_ERR "%s: Unable to create class \n", ALTERA_CVP_DRIVER_NAME);
		pci_unregister_driver(&cvp_driver);
        goto exit;
    }

    if (device_create(cvp_drv_class, NULL, cvp_dev.dev,
                NULL, ALTERA_CVP_DEVFILE) == NULL) {
		printk(KERN_ERR "%s: Unable to create device in cvp class\n", ALTERA_CVP_DRIVER_NAME);
    	class_destroy(cvp_drv_class);
		pci_unregister_driver(&cvp_driver);
        goto exit;
    }

	cvp_dev.remain_size = 0;
	atomic_set(&cvp_dev.is_available, 1);
exit:
	return rc;
}

static void __exit altera_cvp_exit(void)
{
    device_destroy(cvp_drv_class, cvp_dev.dev);
    class_destroy(cvp_drv_class);
	cdev_del(&cvp_dev.cdev);
	unregister_chrdev_region(MKDEV(altera_cvp_major, 0), 1);
	pci_unregister_driver(&cvp_driver);
}

module_init(altera_cvp_init);
module_exit(altera_cvp_exit);

MODULE_AUTHOR("Altera Corporation <support@altera.com>");
MODULE_DESCRIPTION("Configuration driver for Altera CvP-capable FPGAs");
MODULE_VERSION(ALTERA_CVP_DRIVER_VERSION);
MODULE_LICENSE("Dual BSD/GPL");

