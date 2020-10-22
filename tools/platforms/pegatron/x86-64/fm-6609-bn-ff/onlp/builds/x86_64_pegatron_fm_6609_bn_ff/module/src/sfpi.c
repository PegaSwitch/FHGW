/************************************************************
 * <bsn.cl fy=2014 v=onl>
 *
 *        Copyright 2014, 2015 Big Switch Networks, Inc.
 *
 * Licensed under the Eclipse Public License, Version 1.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 *        http://www.eclipse.org/legal/epl-v10.html
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
 * either express or implied. See the License for the specific
 * language governing permissions and limitations under the
 * License.
 *
 * </bsn.cl>
 ************************************************************
 *
 *
 ***********************************************************/
#include <onlp/platformi/sfpi.h>
#include <x86_64_pegatron_fm_6609_bn_ff/x86_64_pegatron_fm_6609_bn_ff_config.h>
#include "x86_64_pegatron_fm_6609_bn_ff_log.h"
#include <onlplib/i2c.h>
#include <x86_64_pegatron_fm_6609_bn_ff/x86_64_pegatron_fm_6609_bn_ff_i2c_table.h>

#define NUM_OF_SFP_PORT 48
#define NUM_OF_QSFP_PORT 8

typedef struct sfpmap_s {
    int port;
    uint8_t present_channel;
    uint8_t present_cpld;
    uint8_t offset;
    uint8_t bit;
} sfpmap_t;

static sfpmap_t sfpmap__[] =
{
        { }, /* Not used */
        {  1, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR1, 0x01 },
        {  2, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR1, 0x10 },
        {  3, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR2, 0x01 },
        {  4, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR2, 0x10 },
        {  5, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR3, 0x01 },
        {  6, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR3, 0x10 },
        {  7, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR4, 0x01 },
        {  8, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR4, 0x10 },
        {  9, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR5, 0x01 },
        { 10, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR5, 0x10 },
        { 11, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR6, 0x01 },
        { 12, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSCR6, 0x10 },
        { 13, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR1, 0x01 },
        { 14, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR1, 0x10 },
        { 15, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR2, 0x01 },
        { 16, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR2, 0x10 },
        { 17, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR3, 0x01 },
        { 18, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR3, 0x10 },
        { 19, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR4, 0x01 },
        { 20, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR4, 0x10 },
        { 21, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR5, 0x01 },
        { 22, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR5, 0x10 },
        { 23, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR6, 0x01 },
        { 24, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR6, 0x10 },
        { 25, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR7, 0x01 },
        { 26, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR7, 0x10 },
        { 27, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR8, 0x01 },
        { 28, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR8, 0x10 },
        { 29, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR9, 0x01 },
        { 30, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR9, 0x10 },
        { 31, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR10, 0x01 },
        { 32, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR10, 0x10 },
        { 33, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR11, 0x01 },
        { 34, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR11, 0x10 },
        { 35, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR12, 0x01 },
        { 36, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR12, 0x10 },
        { 37, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR13, 0x01 },
        { 38, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR13, 0x10 },
        { 39, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR14, 0x01 },
        { 40, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSCR14, 0x10 },
        { 41, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSCR1, 0x01 },
        { 42, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSCR1, 0x10 },
        { 43, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSCR2, 0x01 },
        { 44, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSCR2, 0x10 },
        { 45, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSCR3, 0x01 },
        { 46, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSCR3, 0x10 },
        { 47, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSCR4, 0x01 },
        { 48, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSCR4, 0x10 },
        { 49, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQSRR, 0x01 },
        { 50, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQSRR, 0x02 },
        { 51, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQSRR, 0x04 },
        { 52, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQSRR, 0x08 },
        { 53, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQSRR, 0x10 },
        { 54, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQSRR, 0x20 },
        { 55, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQSRR, 0x40 },
        { 56, PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQSRR, 0x80 },
};

#define SFP_GET(_port) (sfpmap__ + _port)

static int
Get_SFPI_Status(int port, int *value)
{
    sfpmap_t *sfp = SFP_GET(port);
    uint8_t data = 0x0;
	int bus_no = 0;
	

    if (sfp->port != port)
        return ONLP_STATUS_E_INTERNAL;
	
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
    data  = (uint8_t) onlp_i2c_readb(bus_no, 
                      sfp->present_cpld, sfp->offset, ONLP_I2C_F_FORCE);
    if (~data & sfp->bit)
        *value = 1;
    else
        *value = 0;
    return ONLP_STATUS_OK;
}

int
onlp_sfpi_init(void)
{
    return ONLP_STATUS_OK;
}

int
onlp_sfpi_bitmap_get(onlp_sfp_bitmap_t* bmap)
{
    int p;
    for(p = 1; p <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT); p++) {
        AIM_BITMAP_SET(bmap, p);
    }
    return ONLP_STATUS_OK;
}

int
onlp_sfpi_is_present(int port)
{
    /*
     * Return 1 if present.
     * Return 0 if not present.
     * Return < 0 if error.
     */
    int present = -1;

    if (Get_SFPI_Status(port, &present) != 0) {
        AIM_LOG_ERROR("Unable to read present status from port(%d)\r\n", port);
        return ONLP_STATUS_E_INTERNAL;
    }

    return present;
}

int
onlp_sfpi_presence_bitmap_get(onlp_sfp_bitmap_t* dst)
{
    int ii = 1;
    int rc = 0;

    for (;ii <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT); ii++) {
        rc = onlp_sfpi_is_present(ii);
        AIM_BITMAP_MOD(dst, ii, (1 == rc) ? 1 : 0);
    }

    return ONLP_STATUS_OK;
}

int
onlp_sfpi_rx_los_bitmap_get(onlp_sfp_bitmap_t* dst)
{   
    int ii = 1;
    int rc = 0;
    AIM_BITMAP_CLR_ALL(dst);
    for (;ii <= (NUM_OF_SFP_PORT); ii++) {
        rc = onlp_sfpi_is_present(ii);
        AIM_BITMAP_MOD(dst, ii, (1 == rc) ? 1 : 0);
    }
    return ONLP_STATUS_OK;
}

static int _swap_zsfp_scl_mux(int port, int cpld, int bus_no)
{	
    int zsmcr=0;
    int data;
    if((port >=1) && (port <= 12)) {
        zsmcr = PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_ZSMCR;
        data = port;
    } else if((port >=13) && (port <= 40)) {
        zsmcr = PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_ZSMCR;
        data = port-12;
    } else if((port >=41) && (port <= 56)) {
        zsmcr = PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZSMCR;
        data = port-40;
    } else
        return -1;
    onlp_i2c_writeb(bus_no,
            cpld, zsmcr, data, ONLP_I2C_F_FORCE);
    return 0;
}

/*
 * This function reads the SFPs idrom and returns in
 * in the data buffer provided.
 */
int
onlp_sfpi_eeprom_read(int port, uint8_t data[256])
{
    sfpmap_t *sfp = NULL;
    int i;
    int rv;
	int bus_no;
    
    if(onlp_sfpi_is_present(port) == 1) {
        sfp = SFP_GET(port);
		bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
        /* Setting CPU I2C Bus connect to one of ZSFP module, */	
        if(_swap_zsfp_scl_mux(port, sfp->present_cpld, bus_no) <0) {
            rv = ONLP_STATUS_E_MISSING;
            goto error;
        }
        for(i=0; i<256; i++) {
            data[i] = onlp_i2c_readb(bus_no, 
                        0x50, i, ONLP_I2C_F_FORCE);
        }
        rv = ONLP_STATUS_OK;
    } else {
        rv = ONLP_STATUS_E_MISSING;
    }
error:
    return rv;
}

/**
 * @brief Read a byte from an address on the given SFP port's bus.
 * @param port The port number.
 * @param devaddr The device address.
 * @param addr The address.
 */
int onlp_sfpi_dev_readb(int port, uint8_t devaddr, uint8_t addr)
{
    int data=0;
    sfpmap_t *sfp = NULL;
    int rv;
	int bus_no;
	
    if(onlp_sfpi_is_present(port) == 1) {
        sfp = SFP_GET(port);
		bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
        /* Setting CPU I2C Bus connect to one of ZSFP module, */
        if(_swap_zsfp_scl_mux(port, sfp->present_cpld, bus_no) <0) {
            rv = ONLP_STATUS_E_MISSING;
            goto error;
        }
        data = onlp_i2c_readb(bus_no, 
                              devaddr, addr, ONLP_I2C_F_FORCE);
        rv = ONLP_STATUS_OK;
    } else {
        rv = ONLP_STATUS_E_MISSING;
    }
error:
    return (rv == ONLP_STATUS_OK) ? data : rv;
}


/**
 * @brief Read a byte from an address on the given SFP port's bus.
 * @param port The port number.
 * @param devaddr The device address.
 * @param addr The address.
 * @returns The word if successful, error otherwise.
 */
int onlp_sfpi_dev_readw(int port, uint8_t devaddr, uint8_t addr)
{
    int data=0;
    sfpmap_t *sfp = NULL;
    int rv;
	int bus_no;

    if(onlp_sfpi_is_present(port) == 1) {
        sfp = SFP_GET(port);
		bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
        /* Setting CPU I2C Bus connect to one of ZSFP module, */
        if(_swap_zsfp_scl_mux(port, sfp->present_cpld, bus_no) <0) {
            rv = ONLP_STATUS_E_MISSING;
            goto error;
        }

        data = onlp_i2c_readw(bus_no, 
                              devaddr, addr, ONLP_I2C_F_FORCE);
        rv = ONLP_STATUS_OK;
    } else {
        rv = ONLP_STATUS_E_MISSING;
    }
error:
    return (rv == ONLP_STATUS_OK) ? data : rv;
}

int onlp_sfpi_control_supported(int port, onlp_sfp_control_t control, int *rv)
{
	*rv = 0;
	if(port >= 1 && port < NUM_OF_SFP_PORT){
		switch (control) {
		case ONLP_SFP_CONTROL_RX_LOS:
		case ONLP_SFP_CONTROL_TX_FAULT:
		case ONLP_SFP_CONTROL_TX_DISABLE:
			*rv = 1;
			break;
		default:
			break;
		}
	}
	return ONLP_STATUS_OK;
}

int onlp_sfpi_control_set(int port, onlp_sfp_control_t control, int value)
{
	int ret = ONLP_STATUS_OK;
	sfpmap_t *sfp = NULL;
	int mask = 0;
	int data = 0;
	int bus_no;
	if(port >= 1 && port < NUM_OF_SFP_PORT){
		sfp = SFP_GET(port);
		switch (control) {
		case ONLP_SFP_CONTROL_TX_DISABLE:
			bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
			data  = (uint8_t) onlp_i2c_readb(bus_no,
							sfp->present_cpld, sfp->offset, ONLP_I2C_F_FORCE);
			if((port%2) == 0) {
				mask = 0x80;
			} else {
				mask = 0x08;
			}
			if(value) {
				data |= mask;
			} else {
				data &= ~mask;
			}
			onlp_i2c_writeb(bus_no,
							sfp->present_cpld, sfp->offset, data, ONLP_I2C_F_FORCE);
			break;
		default:
			return ONLP_STATUS_E_UNSUPPORTED;
		}
	} else
		ret = ONLP_STATUS_E_UNSUPPORTED;
	return ret;
}

int onlp_sfpi_control_get(int port, onlp_sfp_control_t control, int *value)
{
	int ret = ONLP_STATUS_OK;
	sfpmap_t *sfp = NULL;
	int mask = 0;
	int data = 0;
	int bus_no;
	if(port >= 1 && port < NUM_OF_SFP_PORT){
		sfp = SFP_GET(port);
		bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
		data  = (uint8_t) onlp_i2c_readb(bus_no,
						sfp->present_cpld, sfp->offset, ONLP_I2C_F_FORCE);
		switch (control) {
		case ONLP_SFP_CONTROL_RX_LOS:
			if((port%2) == 0) {
				mask = 0x20;
			} else {
				mask = 0x02;
			}
			break;
		case ONLP_SFP_CONTROL_TX_FAULT:
			if((port%2) == 0) {
				mask = 0x40;
			} else {
				mask = 0x04;
			}
			break;
		case ONLP_SFP_CONTROL_TX_DISABLE:
			if((port%2) == 0) {
				mask = 0x80;
			} else {
				mask = 0x08;
			}
			break;
		default:
			ret = ONLP_STATUS_E_UNSUPPORTED;
			goto error;
			break;
		}
		if(data & mask) 
			*value = 1;
		else
			*value = 0;
	} else
		ret = ONLP_STATUS_E_UNSUPPORTED;
error:
	return ret;
}

int
onlp_sfpi_denit(void)
{
    return ONLP_STATUS_OK;
}
