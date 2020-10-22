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
 * Fan Platform Implementation Defaults.
 *
 ***********************************************************/
#include <math.h>
#include <onlp/platformi/fani.h>
#include "x86_64_pegatron_fm_6609_bn_ff_int.h"
#include <onlplib/i2c.h>
#include <x86_64_pegatron_fm_6609_bn_ff/x86_64_pegatron_fm_6609_bn_ff_i2c_table.h>

#define PEGA_FM_6609_BN_FF_I2C_FAN_PWM               0x10
#define PEGA_FM_6609_BN_FF_I2C_FAN_PWM_MODE          0x11
#define PEGA_FM_6609_BN_FF_I2C_FAN_RPM_INNER         0x20
#define PEGA_FM_6609_BN_FF_I2C_FAN_RPM_OUTER         0x30
#define PEGA_FM_6609_BN_FF_I2C_FAN_STATUS            0x40
#define PEGA_FM_6609_BN_FF_I2C_FAN_CONTROL_STATUS    0x20
#define PEGA_FM_6609_BN_FF_I2C_LED_CONTROL_MODE      0x30
#define PEGA_FM_6609_BN_FF_I2C_LED_GREEN             0x40
#define PEGA_FM_6609_BN_FF_I2C_LED_AMBER             0x50
#define PEGA_FM_6609_BN_FF_FAN_NUMBER                5

static onlp_fan_info_t fan_info[] = {
    { }, /* Not used */
    { { FAN_OID_FANA_OUTLET, "FANTRAY A Outlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FANA_INLET, "FANTRAY A Inlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FANB_OUTLET, "FANTRAY B Outlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FANB_INLET, "FANTRAY B Inlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FANC_OUTLET, "FANTRAY C Outlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FANC_INLET, "FANTRAY C Inlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FAND_OUTLET, "FANTRAY D Outlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FAND_INLET, "FANTRAY D Inlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FANE_OUTLET, "FANTRAY E Outlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FANE_INLET, "FANTRAY E Inlet", 0 }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FAN_PSUA,  "PSU-A Fan", PSU_OID_PSUA }, ONLP_FAN_STATUS_PRESENT },
    { { FAN_OID_FAN_PSUB,  "PSU-B Fan", PSU_OID_PSUB }, ONLP_FAN_STATUS_PRESENT },
};

/*
 * This function will be called prior to all of onlp_fani_* functions.
 */
int
onlp_fani_init(void)
{
    return ONLP_STATUS_OK;
}

int
Get_Sys_FAN_Status(onlp_fan_info_t* info, int fid)
{
    int rv = 0, data=0;
    int istatus=0, fan_func_sel, fan_id;
	int percent;
	int bus_no;
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_3;

    fan_id = (fid -1)/2;
    fan_func_sel = PEGA_FM_6609_BN_FF_I2C_FAN_STATUS | fan_id;

    istatus  = onlp_i2c_readb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_MCU, fan_func_sel, ONLP_I2C_F_FORCE);

    if ( (istatus & 0x80) != 0x0 ) {
        info->status = ONLP_FAN_STATUS_FAILED;
        rv = ONLP_STATUS_E_INTERNAL;
        goto error;
    }

    info->status = ONLP_FAN_STATUS_PRESENT;
    info->status |= ONLP_FAN_STATUS_F2B;

    if (fid%2) {
        // Get Outlet FANs
        fan_func_sel = PEGA_FM_6609_BN_FF_I2C_FAN_RPM_OUTER | fan_id;
    } else {
        // Get Inlet FANs
        fan_func_sel = PEGA_FM_6609_BN_FF_I2C_FAN_RPM_INNER | fan_id;
    }

    percent  = onlp_i2c_readb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_MCU, PEGA_FM_6609_BN_FF_I2C_FAN_PWM, ONLP_I2C_F_FORCE);
    info->caps |= ONLP_FAN_CAPS_GET_PERCENTAGE;
	info->percentage = percent;

    data = onlp_i2c_readw(bus_no, PEGATRON_FM_6609_BN_FF_I2C_MCU, fan_func_sel, ONLP_I2C_F_FORCE);
    info->rpm = data;
    info->caps |= ONLP_FAN_CAPS_SET_PERCENTAGE;

error:
    return rv;
}

/**
 * @brief Set the fan speed in percentage.
 * @param id The fan OID.
 * @param p The new fan speed percentage.
 * @note This is only relevant if the PERCENTAGE capability is set.
 */
int onlp_fani_percentage_set(onlp_oid_t id, int p)
{
    int rv = ONLP_STATUS_OK;
    int fid = ONLP_OID_ID_GET(id);
    onlp_fan_info_t *f = NULL;
    int i;
	int bus_no;

    if(p <= 0 || p > 100)
        return ONLP_STATUS_E_INVALID;
    switch(fid) {
    case FAN_ID_FANA_OUTLET:
    case FAN_ID_FANA_INLET:
    case FAN_ID_FANB_OUTLET:
    case FAN_ID_FANB_INLET:
    case FAN_ID_FANC_OUTLET:
    case FAN_ID_FANC_INLET:
    case FAN_ID_FAND_OUTLET:
    case FAN_ID_FAND_INLET:
    case FAN_ID_FANE_OUTLET:
    case FAN_ID_FANE_INLET:
        for(i=FAN_ID_FANA_OUTLET; i<=FAN_ID_FANE_INLET; i++) {
            f = &fan_info[fid];
            f->percentage = p;
        } 
		bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_3;
		onlp_i2c_writeb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_MCU, PEGA_FM_6609_BN_FF_I2C_FAN_PWM, p, ONLP_I2C_F_FORCE);
        break;
    default:
        rv = ONLP_STATUS_E_INVALID;
        break;
    }

    return rv;
}

int
Get_Power_FAN_Status(onlp_fan_info_t* info, int fid)
{
    int rv = 0, data = 0x0, val_1 = 0x0, val_2 = 0x0;
    uint8_t psu_addr;
    uint8_t channel;
    int is_present;
	int bus_no;
	
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
    data  = onlp_i2c_readb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_PSR, ONLP_I2C_F_FORCE);

    switch (fid) {
    case FAN_ID_FAN_PSUA:
        channel = PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0;
        psu_addr = PEGATRON_FM_6609_BN_FF_PSU_A;
        is_present = (((data & 0x08) >> 3) == 0) ? 1 : 0; /* 0000 0010 ==> check bit_1 equals 0 or not! */
        break;
    case FAN_ID_FAN_PSUB:
        channel = PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
        psu_addr = PEGATRON_FM_6609_BN_FF_PSU_B;
        is_present = (((data & 0x04) >> 2) == 0) ? 1 : 0; /* 0000 0001 ==> check bit_0 equals 0 or not! */
        break;
    default:
        info->status = ONLP_FAN_STATUS_FAILED;
        return ONLP_STATUS_E_INVALID;
        break;
    }

    /* Means PSU doesn't installed */
    if(is_present == 0) {
        info->status = ONLP_FAN_STATUS_FAILED;
        rv = ONLP_STATUS_E_INTERNAL;
        goto error;
    }

	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + channel;
    data  = onlp_i2c_readw(bus_no, psu_addr, 0x88, ONLP_I2C_F_FORCE);
    if (data <= 0) {
        info->status = ONLP_FAN_STATUS_FAILED;
        rv = ONLP_STATUS_E_INTERNAL;
        goto error;
    }

    info->status = ONLP_FAN_STATUS_PRESENT;

    rv = ONLP_STATUS_OK;
    data  = onlp_i2c_readw(bus_no, psu_addr, 0x90, ONLP_I2C_F_FORCE);
    val_1 = (data & 0xf800) >> 11;
    if (val_1 & 0x10) {
        val_1 = (~val_1 & 0x1f) + 0x1;
        val_1 = val_1 * -1;
    }
    val_2 = data & 0x07ff;
    info->rpm = (int)((pow(2, val_1)) * val_2);

    info->caps |= ONLP_FAN_CAPS_GET_RPM;

error:
    return rv;
}

int
onlp_fani_info_get(onlp_oid_t id, onlp_fan_info_t *info)
{
    int fid = ONLP_OID_ID_GET(id);
    onlp_fan_info_t *f = NULL;
    int rv = 0;

    switch(fid) {
        case FAN_ID_FANA_OUTLET:
        case FAN_ID_FANA_INLET:
        case FAN_ID_FANB_OUTLET:
        case FAN_ID_FANB_INLET:
        case FAN_ID_FANC_OUTLET:
        case FAN_ID_FANC_INLET:
        case FAN_ID_FAND_OUTLET:
        case FAN_ID_FAND_INLET:
        case FAN_ID_FANE_OUTLET:
        case FAN_ID_FANE_INLET:
        f = &fan_info[fid];
        rv = Get_Sys_FAN_Status(f, fid);
        /* Sync local info to incoming pointer */
        memcpy((void *__restrict )info, (void *__restrict )f, sizeof(onlp_fan_info_t));
        break;
    case FAN_ID_FAN_PSUA:
    case FAN_ID_FAN_PSUB:
        f = &fan_info[fid];
        rv = Get_Power_FAN_Status(f, fid);
        /* Sync local info to incoming pointer */
        memcpy((void *__restrict )info, (void *__restrict )f, sizeof(onlp_fan_info_t));
        break;
    default:
        rv = ONLP_STATUS_E_INVALID;
        break;
    }

    return rv;
}
