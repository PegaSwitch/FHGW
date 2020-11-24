#ifndef FHGW_FPGA_DRV_H
#define FHGW_FPGA_DRV_H

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/stddef.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/pci.h>
#include <linux/kthread.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>

#define FHGW_FPGA_VENDOR_ID 		0x1172
#define FHGW_FPGA_DEVICE_ID 		0x0000
#define ANY_ID_ 					(~0)

#define FHGW_FPGA_REG_SIZE		    0x10000000	/* 256M */

struct fhgw_fpga_dev {
  struct pci_dev *pdev;
  void __iomem *regs;
  dev_t devno;
  struct cdev cdev;
  struct device* chardev;
};

#endif /* FHGW_FPGA_DRV_H */
