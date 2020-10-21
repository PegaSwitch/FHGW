#include <linux/init.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/platform_device.h>
#include <linux/delay.h>

static int __init pega_platform_init(void)
{
        printk(KERN_INFO "Hello fm-6609-bn-ff!\n");
}

static void __exit pega_platform_exit(void)
{
}

module_init(pega_platform_init);
module_exit(pega_platform_exit);

MODULE_AUTHOR("Pegatron");
MODULE_DESCRIPTION("Platform devices");
MODULE_LICENSE("GPL");
