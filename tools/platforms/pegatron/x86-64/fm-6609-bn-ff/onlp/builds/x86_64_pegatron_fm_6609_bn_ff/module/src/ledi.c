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
#include <onlp/platformi/ledi.h>
#include "x86_64_pegatron_fm_6609_bn_ff_int.h"
#include <onlplib/i2c.h>
#include <x86_64_pegatron_fm_6609_bn_ff/x86_64_pegatron_fm_6609_bn_ff_i2c_table.h>

static onlp_led_info_t linfo[] =
{
    { }, /* Not used */
    {
        { LED_OID_SYSTEM_STATUS, "System Status LED", 0 },
          ONLP_LED_STATUS_PRESENT,
          ONLP_LED_CAPS_ON_OFF | ONLP_LED_CAPS_ORANGE |
          ONLP_LED_CAPS_ORANGE_BLINKING | ONLP_LED_CAPS_GREEN_BLINKING | ONLP_LED_CAPS_GREEN,
    },
    {
        { LED_OID_FAN_STATUS, "FAN Status LED", 0 },
          ONLP_LED_STATUS_PRESENT,
          ONLP_LED_CAPS_ON_OFF | ONLP_LED_CAPS_ORANGE |
          ONLP_LED_CAPS_ORANGE_BLINKING | ONLP_LED_CAPS_GREEN_BLINKING | ONLP_LED_CAPS_GREEN,
    },
    {
        { LED_OID_POWER_STATUS, "Power Status LED", 0 },
        ONLP_LED_STATUS_PRESENT,
        ONLP_LED_CAPS_ON_OFF | ONLP_LED_CAPS_ORANGE |
        ONLP_LED_CAPS_ORANGE_BLINKING | ONLP_LED_CAPS_GREEN_BLINKING | ONLP_LED_CAPS_GREEN,
    },
    {
        { LED_OID_SYSTEM_LOCATOR, "System Locator LED", 0 },
          ONLP_LED_STATUS_PRESENT,
          ONLP_LED_CAPS_ON_OFF | ONLP_LED_CAPS_BLUE | ONLP_LED_CAPS_BLUE_BLINKING,
    }
};

int
onlp_ledi_init(void)
{
	int bus_no = 0;
    /* Set PSoc Fan-Alert Enable */
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
    onlp_i2c_writeb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_MCR1, 0x08, ONLP_I2C_F_FORCE);
    onlp_i2c_writeb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR1, 0x0, ONLP_I2C_F_FORCE); /* system status & power status OK 	*/
    onlp_i2c_writeb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR2, 0x12, ONLP_I2C_F_FORCE); /* system locator off & fan status OK	*/
    /* 
    LED_Force_On    00
    SLED_EN         1
    */
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0;
    onlp_i2c_writeb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A_LEDCR2, 0x04, ONLP_I2C_F_FORCE);
    
    bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2;
    onlp_i2c_writeb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_MCR1, 0x08, ONLP_I2C_F_FORCE);
    onlp_i2c_writeb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQRSTR1, 0x55, ONLP_I2C_F_FORCE);
    onlp_i2c_writeb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C_ZQRSTR2, 0x55, ONLP_I2C_F_FORCE);
    /* Set LED to green */
    onlp_ledi_mode_set(LED_OID_SYSTEM_STATUS, ONLP_LED_MODE_GREEN);
    onlp_ledi_mode_set(LED_OID_FAN_STATUS, ONLP_LED_MODE_GREEN);
    onlp_ledi_mode_set(LED_OID_POWER_STATUS, ONLP_LED_MODE_GREEN);
    onlp_ledi_mode_set(LED_OID_SYSTEM_LOCATOR, ONLP_LED_MODE_OFF);
    return ONLP_STATUS_OK;
}

int
onlp_ledi_info_get(onlp_oid_t id, onlp_led_info_t* info)
{
    int led_id = 1;

    led_id = ONLP_OID_ID_GET(id);

    switch (led_id) {
    case LED_ID_SYSTEM_STATUS:
    case LED_ID_FAN_STATUS:
    case LED_ID_POWER_STATUS:
    case LED_ID_SYSTEM_LOCATOR:
        /* Sync local info to incoming pointer */
        memcpy((void *__restrict )info, (void *__restrict )&linfo[led_id], sizeof(onlp_led_info_t));
        break;
    default:
        return ONLP_STATUS_E_INTERNAL;
        break;
    }

    return ONLP_STATUS_OK;
}

void Sys_Set_System_Status_LED(onlp_led_mode_t mode)
{
    uint8_t iout = 0;
	int bus_no = 0;
	
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
    /* Get current
     */
    iout  = (uint8_t) onlp_i2c_readb(bus_no, 
    	PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 
    	PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR1,
        ONLP_I2C_F_FORCE);
    iout &= 0x1F;

    if (mode == ONLP_LED_MODE_GREEN) {
        iout |= (0 << 5);	
    } else if(mode == ONLP_LED_MODE_ORANGE){
        iout |= (1 << 5);
    } else if(mode == ONLP_LED_MODE_GREEN_BLINKING){
        iout |= (3 << 5);
    } else if(mode == ONLP_LED_MODE_ORANGE_BLINKING){
        iout |= (4 << 5);
    } else{
        iout |= (2 << 5);
    }
	onlp_i2c_writeb(bus_no, 
		PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 
		PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR1,
        iout, ONLP_I2C_F_FORCE);
}

void Sys_Set_Fan_Status_LED(onlp_led_mode_t mode)
{
    uint8_t iout = 0;
	int bus_no = 0;
	
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
    /* Get current */
    iout  = (uint8_t) onlp_i2c_readb(bus_no, 
    	PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 
    	PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR2,
        ONLP_I2C_F_FORCE);
    iout &= 0xF8;

    if (mode == ONLP_LED_MODE_GREEN) {
        iout |= (0 << 0);
    } else if(mode == ONLP_LED_MODE_ORANGE){
        iout |= (1 << 0);
    } else if(mode == ONLP_LED_MODE_GREEN_BLINKING){
        iout |= (3 << 0);
    } else if(mode == ONLP_LED_MODE_ORANGE_BLINKING){
        iout |= (4 << 0);
    } else{
        iout |= (2 << 0);
    }
	onlp_i2c_writeb(bus_no, 
		PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 
		PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR2,
        iout, ONLP_I2C_F_FORCE);
}

void Sys_Set_Power_Status_LED(onlp_led_mode_t mode)
{
    uint8_t iout = 0;
	int bus_no = 0;
	
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
    /* Get current
     */
    iout  = (uint8_t) onlp_i2c_readb(bus_no, 
    	PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 
    	PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR1,
        ONLP_I2C_F_FORCE);
    iout &= 0xE3;

    if (mode == ONLP_LED_MODE_GREEN) {
        iout |= (0 << 2);
    } else if(mode == ONLP_LED_MODE_ORANGE){
        iout |= (1 << 2);
    } else if(mode == ONLP_LED_MODE_GREEN_BLINKING){
        iout |= (3 << 2);
    } else if(mode == ONLP_LED_MODE_ORANGE_BLINKING){
        iout |= (4 << 2);
    } else{
        iout |= (2 << 2);
    }
	onlp_i2c_writeb(bus_no, 
		PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 
		PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR1,
        iout, ONLP_I2C_F_FORCE);
}

void Sys_Set_System_Locator_LED(onlp_led_mode_t mode)
{
    uint8_t iout;
	int bus_no = 0;
	
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
    /* Get current
     */
    iout  = (uint8_t) onlp_i2c_readb(bus_no, 
    	PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 
    	PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR2,
        ONLP_I2C_F_FORCE);
    iout &= 0xCF;

    if (mode == ONLP_LED_MODE_BLUE) {
        iout |= (0 << 4);
    } else if(mode == ONLP_LED_MODE_BLUE_BLINKING){
        iout |= (2 << 4);
    } else{
        iout |= (1 << 4);
    }
        onlp_i2c_writeb(bus_no, 
			PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 
			PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_LEDCR2,
        iout, ONLP_I2C_F_FORCE);
}

int
onlp_ledi_mode_set(onlp_oid_t id, onlp_led_mode_t mode)
{
    int led_id;

    led_id = ONLP_OID_ID_GET(id);
    switch (led_id) {
    case LED_ID_SYSTEM_STATUS:
        Sys_Set_System_Status_LED(mode);
        break;
    case LED_ID_FAN_STATUS:
        Sys_Set_Fan_Status_LED(mode);
        break;
    case LED_ID_POWER_STATUS:
        Sys_Set_Power_Status_LED(mode);
        break;
    case LED_ID_SYSTEM_LOCATOR:
        Sys_Set_System_Locator_LED(mode);
        break;
    default:
        return ONLP_STATUS_E_INTERNAL;
        break;
    }

    return ONLP_STATUS_OK;
}

