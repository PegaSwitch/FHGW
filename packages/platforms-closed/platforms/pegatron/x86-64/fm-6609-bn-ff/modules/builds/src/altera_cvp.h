/*
 * altera_cvp.h -- Altera CvP driver header file
 *
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

#ifndef _ALTERA_CVP_H
#define _ALTERA_CVP_H

#include <linux/bitfield.h>
#define ALTERA_CVP_DRIVER_NAME    "Altera CvP"
#define ALTERA_CVP_DEVFILE        "altera_cvp"
#define ALTERA_CVP_DRIVER_VERSION "0.1.6"

#define NUM_VSEC_BYTES	      0x5c /* number of bytes dedicated to VSEC in S10 */
#define NUM_VSEC_REGS NUM_VSEC_BYTES/4 /* number of VSEC registers for CvP */
#define BYTES_IN_REG             4 /* number of bytes in each VSEC register */

#define ERR_CHK_INTERVAL      1024 /* only check for CRC errors every this many 32-bit words */
#define MIN_WAIT                 2 /* number of jiffies for unit wait period */
#define US_PER_JIFFY  (1000000/HZ) /* number of microseconds per jiffy */
#define DELAY_PER_SEND_US      50  /* Delay in microseconds per send_data "block" */
#define DWORDS_TO_SEND		 2 /* Number of DWORDs to send in each PCIe send */

#define SEND_BUF_INITIAL_SIZE 262144

#define OFFSET_VSEC          0xd00 /* byte offset of VSEC register block for CvP */
#define OFFSET_CVP_STATUS     0x1E /* byte offsets of registers within VSEC */
#define OFFSET_CVP_MODE_CTRL  0x20
#define OFFSET_CVP_NUMCLKS    0x21 /* Not needed in Stratix10 */
#define OFFSET_CVP_DATA2      0x24 /* POF Data2, high bits in 64-bit DW POF Data */
#define OFFSET_CVP_DATA       0x28 /* POF Data1 for DW data, is the 32-bit POF data reg */
#define OFFSET_CVP_PROG_CTRL  0x2C
#define OFFSET_UNC_IE_STATUS  0x34
#define OFFSET_CVP_CREDITS    0x49 /* should be the credits register (byte). */

#define MASK_DATA_ENCRYPTED    0x01 /* bit 0 of CVP_STATUS */
#define MASK_DATA_COMPRESSED   0x02 /* bit 1 of CVP_STATUS */
#define MASK_CVP_CONFIG_READY  0x04 /* bit 2 of CVP_STATUS */
#define MASK_CVP_CONFIG_ERROR  0x08 /* bit 3 of CVP_STATUS */
#define MASK_CVP_EN            0x10 /* bit 4 of CVP_STATUS */
#define MASK_USER_MODE         0x20 /* bit 5 of CVP_STATUS */
#define MASK_PLD_CLK_IN_USE    0x01 /* bit 8 of CVP_STATUS (bit 0 of byte @ CVP_STATUS+1) */
#define MASK_CVP_CONFIG_SUCCESS 0x08 /* bit 10 of CVP_STATUS (bit 3 of byte @ CVP_STATUS+1)*/
#define MASK_CVP_MODE          0x01 /* bit 0 of CVP_MODE_CTRL */
#define MASK_PLD_DISABLE       0X02 /* bit 1 of CVP_MODE_CTRL, was MASK_HIP_CLK_SEL */
#define MASK_CVP_CONFIG        0x01 /* bit 0 of CVP_PROG_CTRL */
#define MASK_START_XFER        0x02 /* bit 1 of CVP_PROG_CTRL */
#define MASK_CVP_CFG_ERR_LATCH 0x20 /* bit 5 of UNC_IE_STATUS */
#define ALT_VSC_EXT_CAP_ID	GENMASK(15,0)
#define ALT_VSC_VERSION		GENMASK(19,16)
#define ALT_VSC_NCO		GENMASK(31,20)
#define ALT_VSH_VSEC_ID		GENMASK(15,0)
#define ALT_VSH_VSEC_REV	GENMASK(19,16)
#define ALT_VSH_VSEC_LEN	GENMASK(31,20)

struct altera_cvp_dev {
	struct cdev cdev;        /* Char device structure */
	struct pci_dev *pci_dev; /* PCI device structure handle */
	void __iomem *wr_addr;   /* Address to use for PCI memory writes */
	dev_t dev;               /* Major and minor numbers for char device */
	int vsec_offset;	 /* VSEC register offset */
	u8 remain[3];            /* Byte remainder from last write operation */
	char remain_size;        /* Number of bytes currently in remainder */
	atomic_t is_available;   /* Flag to enforce single-open */
        struct io_mapping* cvp_io_mapping;
};

/* CvP bits */
enum {  DATA_ENCRYPTED = 0,
	DATA_COMPRESSED,
	CVP_CONFIG_READY,
	CVP_CONFIG_ERROR,
	CVP_CONFIG_SUCCESS,
	CVP_EN,
	USER_MODE,
	PLD_CLK_IN_USE,
	CVP_MODE,
	PLD_DISABLE,  /* Was HIP_CLK_SEL */
	CVP_CONFIG,
	START_XFER,
	CVP_CFG_ERR_LATCH
};

#endif /* _ALTERA_CVP_H */
