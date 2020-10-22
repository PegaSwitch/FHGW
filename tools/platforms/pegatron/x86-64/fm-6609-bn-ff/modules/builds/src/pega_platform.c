#include <linux/init.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/i2c.h>
#include <linux/platform_device.h>
#include <linux/delay.h>
#include <linux/platform_data/pca954x.h>

#define bus_id(id)  (id)

static struct pca954x_platform_mode pca9641_mode[] = {
        { .adap_id = bus_id(1), }
};

static struct pca954x_platform_data pca9641_data = {
        .modes = pca9641_mode,
        .num_modes = 1,
};

static struct i2c_board_info i2c_PCA9641_info = {
        .type = "pca9641",
        .flags = 0,
        .addr = 0x71,
        .platform_data = &pca9641_data,
};

static struct pca954x_platform_mode pca9544_modes[] = {
        {.adap_id = bus_id(2),}, {.adap_id = bus_id(3),},
        {.adap_id = bus_id(4),}, {.adap_id = bus_id(5),}
};

static struct pca954x_platform_data pca9544_data = {
        .modes = pca9544_modes,
        .num_modes = 4,
};

static struct i2c_board_info i2c_PCA9544_info = {
        .type = "pca9544",
        .flags = 0,
        .addr = 0x72,
        .platform_data = &pca9544_data,
};

static struct pca954x_platform_mode pca9548_modes[] = {
        {.adap_id = bus_id(6), }, {.adap_id = bus_id(7), },
        {.adap_id = bus_id(8), }, {.adap_id = bus_id(9), },
        {.adap_id = bus_id(10),}, {.adap_id = bus_id(11),},
        {.adap_id = bus_id(12),}, {.adap_id = bus_id(13),}
};

static struct pca954x_platform_data pca9548_data = {
        .modes = pca9548_modes,
        .num_modes = 8,
};

static struct i2c_board_info i2c_PCA9548_info = {
        .type = "pca9548",
        .flags = 0,
        .addr = 0x73,
        .platform_data = &pca9548_data,
};

#define PLATFORM_CLIENT_MAX_NUM 50 /*A big enough number for sum of i2cdev_list[i].size */
static int client_list_index = 0;
static struct i2c_client *client_list[PLATFORM_CLIENT_MAX_NUM] = {0};

////////////////////////////////////////////////////////////////////////////////

static int __init pega_platform_init(void)
{
        struct i2c_adapter *adap = NULL;
        int ret = 0;

        adap = i2c_get_adapter(bus_id(0));
        if (adap == NULL) {
                printk("platform get adapter fail\n");
                return -1;
        }

        i2c_put_adapter(adap);
        client_list[client_list_index] = i2c_new_device(adap, &i2c_PCA9641_info);
        client_list_index++;

	adap = i2c_get_adapter(bus_id(1));
        client_list[client_list_index] = i2c_new_device(adap, &i2c_PCA9544_info);
        client_list_index++;
        client_list[client_list_index] = i2c_new_device(adap, &i2c_PCA9548_info);
        client_list_index++;

        printk("platform_init done\n");
        return ret;
}

static void __exit pega_platform_exit(void)
{
        int i;

        for (i=client_list_index-1; i>=0; i--) {
                i2c_unregister_device(client_list[i]);
        }
        printk("platform_exit done\n");
}

module_init(pega_platform_init);
module_exit(pega_platform_exit);

MODULE_AUTHOR("Pegatron");
MODULE_DESCRIPTION("Platform devices");
MODULE_LICENSE("GPL");
