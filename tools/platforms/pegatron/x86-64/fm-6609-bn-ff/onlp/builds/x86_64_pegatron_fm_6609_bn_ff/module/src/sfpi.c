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

#define NUM_OF_SFP_PORT 8
#define NUM_OF_QSFP_PORT 1
#define NUM_OF_SFPPLUS_PORT 1

typedef struct sfp_func_s {
    uint8_t offset;
    uint8_t mask;
} sfp_func_t;

typedef struct sfpmap_s {
    int port;
    uint8_t present_channel;
    uint8_t present_cpld;
    uint8_t offset;
    uint8_t mask;
	sfp_func_t lpmode;
	sfp_func_t reset;
	sfp_func_t tx_dis;
} sfpmap_t;

static sfpmap_t sfpmap__[] =
{
	{/*.port, .present_channel,  .present_cpld,  .offset, mask, lpmode:{offset, mask}, reset:{offset, mask},  tx_dis:{offset, mask}*/}, /* Not used */
	{  1, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR1, 0x01, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR1, 0x08} },
	{  2, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR1, 0x10, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR1, 0x80} },
	{  3, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR2, 0x01, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR2, 0x08} },
	{  4, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR2, 0x10, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR2, 0x80} },
	{  5, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR3, 0x01, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR3, 0x08} },
	{  6, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR3, 0x10, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR3, 0x80} },
	{  7, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR4, 0x01, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR4, 0x08} },
	{  8, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR4, 0x10, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR4, 0x80} },
	{  9, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR5, 0x20, {FM_6609_BN_FF_CPLD_B_SCR5, 0x04}, {FM_6609_BN_FF_CPLD_B_SCR5, 0x03}, {0xFF, 0xFF} },
	{ 10, FM_6609_BN_FF_I2C_MUX_CH1, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_SCR6, 0x01, {0xFF, 0xFF}, {0xFF, 0xFF}, {FM_6609_BN_FF_CPLD_B_SCR6, 0x08} },
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
	
	bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
    data  = (uint8_t) onlp_i2c_readb(bus_no, 
                      sfp->present_cpld, sfp->offset, ONLP_I2C_F_FORCE);
    if (~data & sfp->mask)
        *value = 1;
    else
        *value = 0;
    return ONLP_STATUS_OK;
}

int
onlp_sfpi_init(void)
{
	int port = 0;
	
    for(port = 1; port <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT); port++) {
		//SFP and SFP+ module needs to disable TX when initialize. 
		if((port >= 1 && port <= NUM_OF_SFP_PORT) ||
			(port == (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT))){
			onlp_sfpi_control_set(port, ONLP_SFP_CONTROL_TX_DISABLE, 0);
		}
    }
    for(port = (NUM_OF_SFP_PORT+1); port <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT); port++) {
		//QSFP module needs to setting reset register. 
		onlp_sfpi_control_set(port, ONLP_SFP_CONTROL_RESET, 0);
    }
    return ONLP_STATUS_OK;
}

int
onlp_sfpi_bitmap_get(onlp_sfp_bitmap_t* bmap)
{
    int p;
    for(p = 1; p <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT); p++) {
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

    for (;ii <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT); ii++) {
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
	//SFP module
    for (;ii <= (NUM_OF_SFP_PORT); ii++) {
        rc = onlp_sfpi_is_present(ii);
        AIM_BITMAP_MOD(dst, ii, (1 == rc) ? 1 : 0);
    }
	//SFP+ module
	rc = onlp_sfpi_is_present((NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT));
	AIM_BITMAP_MOD(dst, ii, (1 == rc) ? 1 : 0);
    return ONLP_STATUS_OK;
}

static int _swap_zsfp_scl_mux(int port, int cpld, int bus_no)
{	
    int zsmcr=0;
    int data;
    if((port >=1) && (port <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT))) {
        zsmcr = FM_6609_BN_FF_CPLD_B_ZSMCR;
        data = port;
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
		bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
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
		bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
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
		bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
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
	//For SFP module and SFP+ module
	if((port >= 1 && port <= NUM_OF_SFP_PORT) || 
		(port == (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT))){
		switch (control) {
		case ONLP_SFP_CONTROL_TX_DISABLE:
			*rv = 1;
			break;
		default:
			break;
		}
	}
	//For QSFP module
	if(port > NUM_OF_SFP_PORT && port <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT)){
		switch (control) {
		case ONLP_SFP_CONTROL_LP_MODE:
		case ONLP_SFP_CONTROL_RESET:
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
	sfp_func_t *lpmode = NULL;
	sfp_func_t *reset = NULL;
	sfp_func_t *tx_dis = NULL;
	int mask = 0;
	int data = 0;
	int bus_no;
	int reg = 0;
	int tmp = 0;
	
	if(port > (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT))
		return ONLP_STATUS_E_UNSUPPORTED;
	
	sfp = SFP_GET(port);
	bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;
	if(port >= 1 && port <= NUM_OF_SFP_PORT){	//SFP module
		switch (control) {
		case ONLP_SFP_CONTROL_TX_DISABLE:
			tx_dis = &sfp->tx_dis;
			mask = tx_dis->mask;
			reg = tx_dis->offset;
			if(value)
				tmp = tx_dis->mask;	//transmitter disable
			break;			
		default:
			ret = ONLP_STATUS_E_UNSUPPORTED;
			goto error;
			break;
		}
	} else if (port == (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT)){	 //SFP+ module 
		switch (control) {
		case ONLP_SFP_CONTROL_TX_DISABLE:
			tx_dis = &sfp->tx_dis;
			mask = tx_dis->mask;
			reg = tx_dis->offset;
			if(value)
				tmp = tx_dis->mask;	//transmitter disable
			break;
		default:
			ret = ONLP_STATUS_E_UNSUPPORTED;
			goto error;
			break;
		}
	} else if(port > NUM_OF_SFP_PORT && port <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT)){	//QSFP module
		switch (control) {
		case ONLP_SFP_CONTROL_LP_MODE:
			lpmode = &sfp->lpmode;
			mask = lpmode->mask;
			reg = lpmode->offset;
			if(value)
				tmp = lpmode->mask;
			break;
		case ONLP_SFP_CONTROL_RESET:
			reset = &sfp->reset;
			mask = reset->mask;
			reg = reset->offset;
			tmp = value;
			break;
		default:
			ret = ONLP_STATUS_E_UNSUPPORTED;
			goto error;
			break;
		}
	} else {
		ret = ONLP_STATUS_E_UNSUPPORTED;
		goto error;
	}
	data  = (uint8_t) onlp_i2c_readb(bus_no,
						sfp->present_cpld, reg, ONLP_I2C_F_FORCE);
	data &= ~mask;
	//Write new data
	data |= tmp;
	onlp_i2c_writeb(bus_no,
		sfp->present_cpld, reg, data, ONLP_I2C_F_FORCE);
error:
	return ret;
}

int onlp_sfpi_control_get(int port, onlp_sfp_control_t control, int *value)
{
	int ret = ONLP_STATUS_OK;
	sfpmap_t *sfp = NULL;
	sfp_func_t *lpmode = NULL;
	sfp_func_t *reset = NULL;
	sfp_func_t *tx_dis = NULL;
	int mask = 0;
	int data = 0;
	int bus_no;
	int reg = 0;
	
	if(port > (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT))
		return ONLP_STATUS_E_UNSUPPORTED;
		
	sfp = SFP_GET(port);
	bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + sfp->present_channel;	
	if(port >= 1 && port <= NUM_OF_SFP_PORT) {	//SFP module
		switch (control) {
		case ONLP_SFP_CONTROL_TX_DISABLE:
			tx_dis = &sfp->tx_dis;
			mask = tx_dis->mask;
			reg = tx_dis->offset;
			break;
		default:
			ret = ONLP_STATUS_E_UNSUPPORTED;
			goto error;
			break;
		}
	} else if (port == (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT+NUM_OF_SFPPLUS_PORT)){	 	//SFP+ module
		switch (control) {
		case ONLP_SFP_CONTROL_TX_DISABLE:
			tx_dis = &sfp->tx_dis;
			mask = tx_dis->mask;
			reg = tx_dis->offset;
			break;
		default:
			ret = ONLP_STATUS_E_UNSUPPORTED;
			goto error;
			break;
		}
	} else if(port > NUM_OF_SFP_PORT && port <= (NUM_OF_SFP_PORT+NUM_OF_QSFP_PORT)){	//QSFP module
		switch (control) {
		case ONLP_SFP_CONTROL_LP_MODE:
			lpmode = &sfp->lpmode;
			mask = lpmode->mask;
			reg = lpmode->offset;
			break;
		case ONLP_SFP_CONTROL_RESET:
			reset = &sfp->reset;
			mask = reset->mask;
			reg = reset->offset;
			break;
		default:
			ret = ONLP_STATUS_E_UNSUPPORTED;
			goto error;
			break;
		}
	} else {
		ret = ONLP_STATUS_E_UNSUPPORTED;
		goto error;
	}
	data  = (uint8_t) onlp_i2c_readb(bus_no,
						sfp->present_cpld, reg, ONLP_I2C_F_FORCE);
	if(data & mask)
		*value = 1;
	else
		*value = 0;
error:
	return ret;
}

int
onlp_sfpi_denit(void)
{
    return ONLP_STATUS_OK;
}
