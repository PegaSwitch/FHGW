#include "fhgw_fpga_drv.h"
#include "fhgw_fpga_ioctl.h"

dev_t devbase;
char fhgw_fpga_driver_name[] = "pci-fpga";
static struct class* fhgw_fpga_drv_class;

struct fhgw_fpga_dev *fpga_dev;

static const struct pci_device_id fhgw_fpga_id_table[] = {
        { PCI_DEVICE(FHGW_FPGA_VENDOR_ID, FHGW_FPGA_DEVICE_ID), },
        { }, /* all-zero terminator sentinel */
};
MODULE_DEVICE_TABLE(pci, fhgw_fpga_id_table);

static inline u32 
fhgw_fpga_read_reg(u32 offset)
{
	return readl(fpga_dev->regs + offset);
}

static inline void
fhgw_fpga_write_reg(u32 offset, u32 value)
{
	writel(value, fpga_dev->regs + offset);
}

static int fhgw_fpga_drv_open(struct inode* inode, struct file* file)
{
    return 0;
}

static long int fhgw_fpga_drv_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	ioctl_arg_t params = {0};

	switch (cmd) {
		case FHGW_FPGA_READ_VALUE:
			params.value = fhgw_fpga_read_reg(params.regaddr);
			if (copy_to_user((ioctl_arg_t *)arg, &params, sizeof(ioctl_arg_t))) {
				return -EACCES;
			}
			break;

		case FHGW_FPGA_WRITE_VALUE:
			if (copy_from_user(&params, (ioctl_arg_t *)arg, sizeof(ioctl_arg_t))) {
				return -EACCES;
			}
			fhgw_fpga_write_reg(params.regaddr, params.value);
			break;
		default:
			return -EINVAL;
	}

	return 0;
}

static struct file_operations fhgw_fpga_drv_fops = {
        .owner = THIS_MODULE,
        .open = fhgw_fpga_drv_open,
        .unlocked_ioctl = fhgw_fpga_drv_ioctl,
};

static void fhgw_fpga_drv_remove_chardev(void)
{
    device_destroy(fhgw_fpga_drv_class, devbase);
    class_destroy(fhgw_fpga_drv_class);
    cdev_del(&fpga_dev->cdev);
    unregister_chrdev_region(devbase, 1);
}

static int fhgw_fpga_drv_setup_chardev(void)
{

	if (alloc_chrdev_region(&devbase, 0, 1, "fhgw_fpga_drv") < 0)
		return -1;

	cdev_init(&fpga_dev->cdev, &fhgw_fpga_drv_fops);

	if (cdev_add(&fpga_dev->cdev, devbase, 1) < 0)
		goto err_chrdev_region;

	if ((fhgw_fpga_drv_class = class_create(THIS_MODULE, "fhgw_fpga_class")) == NULL) {
		goto err_unregister_chrdev;
	}

	if (device_create(fhgw_fpga_drv_class, NULL, devbase,
					NULL, "fhgw_fpga_dev") == NULL) {
			goto err_destroy_class;
	}

	return 0;

err_destroy_class:
	class_destroy(fhgw_fpga_drv_class);
err_unregister_chrdev:
	cdev_del(&fpga_dev->cdev);
err_chrdev_region:
	unregister_chrdev_region(devbase, 1);
	return -1;
}

static struct
fhgw_fpga_dev *fhgw_fpga_setup_dev(struct pci_dev *pdev)
{
	if(pci_enable_device(pdev)) {
		dev_err(&pdev->dev,"FPGA nic PCI enable failed\n");
		return NULL;
	}

	if(!(pci_resource_flags(pdev, 0) & IORESOURCE_MEM)) {
		dev_err(&pdev->dev,"PCI base address find failure in pci_resource_flags()\n");
		goto out_disable_dev;
	}

	if(pci_request_regions(pdev, fhgw_fpga_driver_name)) {
		dev_err(&pdev->dev, "Could not request PCI mem regions\n");
		goto out_disable_dev;
	}

	pci_set_master(pdev);

	fpga_dev->regs = ioremap(pci_resource_start(pdev, 0), FHGW_FPGA_REG_SIZE);
	if (!fpga_dev->regs)	{
		dev_err(&pdev->dev,"PCI memory remap failure\r\n");
		goto out_release_regions;
	}

	printk("bar0: %lx\r\n", (unsigned int *)fpga_dev->regs);

    if (fhgw_fpga_drv_setup_chardev())
            goto out_release_regions;

	return fpga_dev;

out_release_regions:
	pci_release_regions(pdev);
out_disable_dev:
	pci_disable_device(pdev);
	return NULL;
}

void
fhgw_fpga_remove(struct pci_dev *pdev)
{
	iounmap(fpga_dev->regs);
	pci_release_regions(fpga_dev->pdev);
}

static int
fhgw_fpga_probe(struct pci_dev *pdev , const struct pci_device_id *pent)
{
	fpga_dev = fhgw_fpga_setup_dev(pdev);
	if(fpga_dev == NULL) {
		return -1;
	}

	return 0;
}

static struct pci_driver fhgw_fpga_driver = {
        .name 		=    "fhgw_fpga_drv",
        .id_table 	=    fhgw_fpga_id_table,
        .remove 	=    fhgw_fpga_remove,
        .probe 		=    fhgw_fpga_probe,
        .suspend 	=    NULL,
        .resume 	=    NULL,
        .shutdown 	=    NULL,
        .err_handler =  NULL,
};

static int
fhgw_fpga_init_module(void)
{
	int status;

	fpga_dev = (struct fhgw_fpga_dev *)kmalloc(sizeof(struct fhgw_fpga_dev), GFP_KERNEL);
	if (!fpga_dev)
		return -1;

	status = pci_register_driver(&fhgw_fpga_driver);
	if (status)
		return -1;

	status = fhgw_fpga_drv_setup_chardev();
	if (status)
		return -1;

	return 0;
}

static void
__exit  fhgw_fpga_driver_exit(void)
{
	pci_unregister_driver(&fhgw_fpga_driver);
	fhgw_fpga_drv_remove_chardev();
	kfree(fpga_dev);
	printk("exiting fhgw fpga driver\n");
}

MODULE_DEVICE_TABLE(pci, fhgw_fpga_id_table);
module_init(fhgw_fpga_init_module);
module_exit(fhgw_fpga_driver_exit);
MODULE_LICENSE("GPL");
