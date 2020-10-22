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
 *
 ***********************************************************/
#include <math.h>
#include <onlp/platformi/psui.h>
#include "x86_64_pegatron_fm_6609_bn_ff_int.h"
#include <onlplib/i2c.h>
#include <x86_64_pegatron_fm_6609_bn_ff/x86_64_pegatron_fm_6609_bn_ff_i2c_table.h>
#define PMBUS_MFR_MODEL         0x9A
#define PMBUS_MFR_SERIAL        0x9E
#define PMBUS_MFR_MODEL_LEN     20
#define PMBUS_MFR_SERIAL_LEN    19

static onlp_psu_info_t psu_info[] =  {
        { }, /* Not used */
        {
            {
                PSU_OID_PSUA,
                "PSU-A",
                0,
                {
                    FAN_OID_FAN_PSUA,
                    THERMAL_OID_ON_PSUA_1,
                    THERMAL_OID_ON_PSUA_2,
                    THERMAL_OID_ON_PSUA_3,
                },
            }
        },
        {
            {
                PSU_OID_PSUB,
                "PSU-B",
                0,
                {
                    FAN_OID_FAN_PSUB,
                    THERMAL_OID_ON_PSUB_1,
                    THERMAL_OID_ON_PSUB_2,
                    THERMAL_OID_ON_PSUB_3,
                },
            }
        },
};

int
onlp_psui_init(void)
{
    return ONLP_STATUS_OK;
}

int determine_exponent(int exponent_raw) {	
    int exponent = 0x0;
	exponent = exponent_raw & 0x001f;
	if ((exponent & 0x10) == 0x10) {
		exponent = ((~exponent) & 0x1f) + 0x1;
        exponent = exponent * -1;
	}
	return exponent;
}

double onlp_psui_info_get_data(int data) {	
    int exponent = 0x0, mantissa = 0x0;
	int exponent_raw = 0;

    exponent_raw = (data & 0xf800) >> 11;
    mantissa = data & 0x07ff;
	if((mantissa & 0x0400)==0x0400) {
        mantissa = ((~mantissa) & 0x7ff) + 0x1;
        mantissa = mantissa * -1;
    }
	exponent = determine_exponent(exponent_raw);
    return round((pow(2, exponent)*mantissa)*1000);
}
  
double  get_vout_data(int exponent_raw, int data) {	
    int exponent = 0x0;
	exponent = determine_exponent(exponent_raw);
	return round((pow(2, exponent))*data*1000);
}

int
onlp_psui_info_get(onlp_oid_t id, onlp_psu_info_t* info)
{
    int data = 0x0/*, val_1 = 0x0*/;
    int pid;
	int vout_mode;
    uint8_t psu_addr;
    uint8_t channel;
    uint8_t buffer[ONLP_CONFIG_INFO_STR_MAX];
    int rv;
    onlp_psu_info_t *p = NULL;
    int is_present;
	int bus_no;
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;

    pid = ONLP_OID_ID_GET(id);

    data  = onlp_i2c_readb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B_PSR, ONLP_I2C_F_FORCE);

    switch (pid) {
    case PSU_ID_PSUA:
        channel = PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0;
        psu_addr = PEGATRON_FM_6609_BN_FF_PSU_A;
        is_present = (((data & 0x08) >> 3) == 0) ? 1 : 0; /* 0000 1000 ==> check bit_3 equals 0 or not! */
        break;
    case PSU_ID_PSUB:
        channel = PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
        psu_addr = PEGATRON_FM_6609_BN_FF_PSU_B;
        is_present = (((data & 0x04) >> 2) == 0) ? 1 : 0; /* 0000 0100 ==> check bit_2 equals 0 or not! */
        break;
    default:
        return ONLP_STATUS_E_INVALID;
        break;
    }
    p = &psu_info[pid];

    if(is_present == 0) {	/* Means PSU doesn't installed */
        p->status = ONLP_PSU_STATUS_UNPLUGGED;
        goto end;
    }

	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + channel;
    /* READ VIN RAW DATA*/
    data  = onlp_i2c_readw(bus_no, psu_addr, 0x88, ONLP_I2C_F_FORCE);
    if (data <= 0)
    {
        p->status = ONLP_PSU_STATUS_UNPLUGGED;
        goto end;
    }

    /* PSU is present. */
    p->status = ONLP_PSU_STATUS_PRESENT;
    p->caps |= ONLP_PSU_CAPS_AC;

    /* READ VIN */
    p->caps |= ONLP_PSU_CAPS_VIN;
    p->mvin = onlp_psui_info_get_data(data);

    /* READ IIN */
    data = 0x0;
    data  = onlp_i2c_readw(bus_no, psu_addr, 0x89, ONLP_I2C_F_FORCE);
    p->caps |= ONLP_PSU_CAPS_IIN;
    p->miin = onlp_psui_info_get_data(data);
    /* VOUT_MODE */
    data = 0x0;
    vout_mode  = onlp_i2c_readb(bus_no, psu_addr, 0x20, ONLP_I2C_F_FORCE);
    //val_1 = data & 0x001f;
    //val_1 = (~val_1 & 0x1f) + 0x1;
    //val_1 = val_1 * -1;
    data = 0x0;
    /* READ VOUT */
    data  = onlp_i2c_readw(bus_no, psu_addr, 0x8b, ONLP_I2C_F_FORCE);
    p->caps |= ONLP_PSU_CAPS_VOUT;
    //p->mvout = ((pow(2, val_1)*1000)*data);
	p->mvout = get_vout_data(vout_mode, data);

    /* READ IOUT */
    data = 0x0;
    data  = onlp_i2c_readw(bus_no, psu_addr, 0x8c, ONLP_I2C_F_FORCE);
    p->caps |= ONLP_PSU_CAPS_IOUT;
    p->miout = onlp_psui_info_get_data(data);

    /* READ POut */
    data = 0x0;
    data  = onlp_i2c_readw(bus_no, psu_addr, 0x96, ONLP_I2C_F_FORCE);
    p->caps |= ONLP_PSU_CAPS_POUT;
    p->mpout = onlp_psui_info_get_data(data);

    /* READ PIn */
    data = 0x0;
    data  = onlp_i2c_readw(bus_no, psu_addr, 0x97, ONLP_I2C_F_FORCE);
    p->caps |= ONLP_PSU_CAPS_PIN;
    p->mpin = onlp_psui_info_get_data(data);

    /* READ mfr_model  */
    memset(buffer, 0, sizeof(buffer));
    rv = onlp_i2c_block_read(bus_no, psu_addr, PMBUS_MFR_MODEL, PMBUS_MFR_MODEL_LEN, buffer, ONLP_I2C_F_FORCE);

    buffer[buffer[0] + 1] = 0x00;
    if(rv >= 0){
        aim_strlcpy(p->model, (char *) (buffer+1), (buffer[0] + 1));
    } else {
        strcpy(p->model, "Missing");
    }
    /* READ mfr_serial  */
    memset(buffer, 0, sizeof(buffer));

    rv = onlp_i2c_block_read(bus_no, psu_addr, PMBUS_MFR_SERIAL, PMBUS_MFR_SERIAL_LEN, buffer, ONLP_I2C_F_FORCE);

    buffer[buffer[0] + 1] = 0x00;
    if(rv >= 0){
        aim_strlcpy(p->serial, (char *) (buffer+1), (buffer[0] + 1));
    } else {
        strcpy(p->serial, "Missing");
    }
end:
    /* Sync local info to incoming pointer */
    memcpy((void *__restrict )info, (void *__restrict )p, sizeof(onlp_psu_info_t));
    return ONLP_STATUS_OK;
}
