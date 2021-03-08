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
        {
            {
                PSU_OID_VRM1,
                "TPS53679 (MB  0x60)",
                0,
                {
                    THERMAL_OID_ON_VRM1_1,
                },
            }
        },
        {
            {
                PSU_OID_VRM2,
                "TPS53679 (NPU 0x63)",
                0,
                {
                    THERMAL_OID_ON_VRM2_1,
                },
            }
        },
        {
            {
                PSU_OID_VRM3,
                "TPS53679 (NPU 0x64)",
                0,
                {
                    THERMAL_OID_ON_VRM3_1,
                },
            }
        }
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

double proc_pmbus_raw_data(int data) {	
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
  
double proc_pmbus_vout_raw_data(int exponent_raw, int data) {	
    int exponent = 0x0;
	exponent = determine_exponent(exponent_raw);
	return round((pow(2, exponent))*data*1000);
}

static int onlp_get_pmbus_vin_info(onlp_psu_info_t *p, int bus_no, int address)
{
	int data = 0;

    /* READ VIN */
    data  = onlp_i2c_readw(bus_no, address, PMBUS_VOLTAGE_IN_REG, ONLP_I2C_F_FORCE);
	if(data != -1) {
	    p->caps |= ONLP_PSU_CAPS_VIN;
	    p->mvin = proc_pmbus_raw_data(data);
	}
	return 0;
}

static int onlp_get_pmbus_iin_info(onlp_psu_info_t *p, int bus_no, int address)
{
	int data = 0;

    /* READ IIN */
    data  = onlp_i2c_readw(bus_no, address, PMBUS_CURRENT_IN_REG, ONLP_I2C_F_FORCE);
	if(data != -1) {
	    p->caps |= ONLP_PSU_CAPS_VIN;
	    p->miin = proc_pmbus_raw_data(data);
	}
	return 0;
}

static int onlp_get_pmbus_iout_info(onlp_psu_info_t *p, int bus_no, int address)
{
	int data = 0;

    /* READ IOUT */
    data  = onlp_i2c_readw(bus_no, address, PMBUS_CURRENT_OUT_REG, ONLP_I2C_F_FORCE);
	if(data != -1) {
	    p->caps |= ONLP_PSU_CAPS_IOUT;
	    p->miout = proc_pmbus_raw_data(data);
	}
	return 0;
}

static int onlp_get_vout_info(onlp_psu_info_t *p, int bus_no, int address)
{
	int data = 0;
	int vout_mode;

    /* VOUT_MODE */
    data = 0x0;
    vout_mode  = onlp_i2c_readb(bus_no, address, PMBUS_VOUT_MODE_REG, ONLP_I2C_F_FORCE);
    data = 0x0;
    /* READ VOUT */
    data  = onlp_i2c_readw(bus_no, address, PMBUS_VOLTAGE_OUT_REG, ONLP_I2C_F_FORCE);
    p->caps |= ONLP_PSU_CAPS_VOUT;
	p->mvout = proc_pmbus_vout_raw_data(vout_mode, data);
	return 0;
}

static int onlp_get_tps53679_vout_info(onlp_psu_info_t *p, int bus_no, int address)
{
	int data = 0x0;
	
	/* READ VOUT */
	data  = onlp_i2c_readw(bus_no, address, PMBUS_VOLTAGE_OUT_REG, ONLP_I2C_F_FORCE);
	if(data != -1) {
		p->caps |= ONLP_PSU_CAPS_VOUT;

		if(data != 0)
		   p->mvout = round((0.50 + 0.01 * (data - 1))*10*1000);
	}
	return 0;
}

static int onlp_get_pmbus_pin_info(onlp_psu_info_t *p, int bus_no, int address)
{
	int data = 0;
	
    /* READ PIN */
    data  = onlp_i2c_readw(bus_no, address, PMBUS_POWER_IN_REG, ONLP_I2C_F_FORCE);
	if(data != -1) {
	    p->caps |= ONLP_PSU_CAPS_PIN;
	    p->mpin = proc_pmbus_raw_data(data);
	}
	return 0;
}

static int onlp_get_pmbus_pout_info(onlp_psu_info_t *p, int bus_no, int address)
{
	int data = 0;
	
    /* READ POUT */
    data  = onlp_i2c_readw(bus_no, address, PMBUS_POWER_OUT_REG, ONLP_I2C_F_FORCE);
	if(data != -1) {
	    p->caps |= ONLP_PSU_CAPS_POUT;
	    p->mpout = proc_pmbus_raw_data(data);
	}
	return 0;
}

static int onlp_get_pmbus_mfr_model_info(onlp_psu_info_t *p, int bus_no, int address)
{
	
    uint8_t buffer[ONLP_CONFIG_INFO_STR_MAX];
	int rv = 0;
	
    /* READ mfr_model  */
    memset(buffer, 0, sizeof(buffer));
    rv = onlp_i2c_block_read(bus_no, address, PMBUS_MFR_MODEL, PMBUS_MFR_MODEL_LEN, buffer, ONLP_I2C_F_FORCE);

    buffer[buffer[0] + 1] = 0x00;
    if(rv >= 0){
        aim_strlcpy(p->model, (char *) (buffer+1), (buffer[0] + 1));
    } else {
        strcpy(p->model, "Missing");
    }
	return 0;
}

static int onlp_get_pmbus_mfr_serial_info(onlp_psu_info_t *p, int bus_no, int address)
{
    uint8_t buffer[ONLP_CONFIG_INFO_STR_MAX];
	int rv = 0;
	
    memset(buffer, 0, sizeof(buffer));

    rv = onlp_i2c_block_read(bus_no, address, PMBUS_MFR_SERIAL, PMBUS_MFR_SERIAL_LEN, buffer, ONLP_I2C_F_FORCE);

    buffer[buffer[0] + 1] = 0x00;
    if(rv >= 0){
        aim_strlcpy(p->serial, (char *) (buffer+1), (buffer[0] + 1));
    } else {
        strcpy(p->serial, "Missing");
    }
	return 0;
}

static int onlp_pmbus_vrm_info_get(onlp_psu_info_t *p, int bus_no, int address)
{
	//switch page to channel A
	onlp_i2c_writew(bus_no, address, PMBUS_PAGE_REG, 0x0, ONLP_I2C_F_FORCE);

    /* READ VIN */
	onlp_get_pmbus_vin_info(p, bus_no, address);

    /* READ IIN */
	onlp_get_pmbus_iin_info(p, bus_no, address);

    /* VOUT_MODE */
	//According to different multiphase (or VRM) chip, raw data calculate method will differnet.
	onlp_get_tps53679_vout_info(p, bus_no, address);

    /* READ IOUT */
	/* config phase register */
	onlp_i2c_writew(bus_no, address, PMBUS_PHASE_REG, 0x80, ONLP_I2C_F_FORCE);
	onlp_get_pmbus_iout_info(p, bus_no, address);

	//switch page to Simul Ch-A & Ch-B
	onlp_i2c_writew(bus_no, address, PMBUS_PAGE_REG, 0xff, ONLP_I2C_F_FORCE);

    /* READ POut */
	onlp_get_pmbus_pout_info(p, bus_no, address);

    /* READ PIn */
	onlp_get_pmbus_pin_info(p, bus_no, address);
	
    /* READ mfr_model  */
    strcpy(p->model, "Missing");
	
    /* READ mfr_serial  */
    strcpy(p->serial, "Missing");
	return 0;
}


//TPS53679 (NPU 0x64)
static int onlp_pmbus_vrm3_info_get(onlp_psu_info_t *p)
{
	int bus_no = FM_6609_BN_FF_I2C_BUS1;
	int address = FM_6609_BN_FF_VRM_3;
	
	//switch page to channel B
	onlp_i2c_writew(bus_no, address, PMBUS_PAGE_REG, 0x1, ONLP_I2C_F_FORCE);

    /* READ VIN */
	onlp_get_pmbus_vin_info(p, bus_no, address);

    /* READ IIN */
	onlp_get_pmbus_iin_info(p, bus_no, address);

    /* VOUT_MODE */
	onlp_get_tps53679_vout_info(p, bus_no, address);

    /* READ IOUT */
	/* config phase register */
	onlp_i2c_writew(bus_no, address, PMBUS_PHASE_REG, 0x80, ONLP_I2C_F_FORCE);	
	onlp_get_pmbus_iout_info(p, bus_no, address);

	//switch page to Simul Ch-A & Ch-B
	onlp_i2c_writew(bus_no, address, PMBUS_PAGE_REG, 0xff, ONLP_I2C_F_FORCE);

    /* READ POut */
	onlp_get_pmbus_pout_info(p, bus_no, address);

    /* READ PIn */
	onlp_get_pmbus_pin_info(p, bus_no, address);
	
    /* READ mfr_model  */
    strcpy(p->model, "Missing");
	
    /* READ mfr_serial  */
    strcpy(p->serial, "Missing");
	return 0;
}

static int onlp_psui_vrm_info_get(onlp_psu_info_t *p, int pid)
{
	int bus_no = FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + FM_6609_BN_FF_I2C_MUX_CH2;
    p->status = ONLP_PSU_STATUS_PRESENT;
    p->caps |= ONLP_PSU_CAPS_DC12;
    switch (pid) {
	case PSU_ID_VRM1:
		onlp_pmbus_vrm_info_get(p, bus_no, FM_6609_BN_FF_VRM_1);
	case PSU_ID_VRM2:
		bus_no = FM_6609_BN_FF_I2C_BUS1;
		onlp_pmbus_vrm_info_get(p, bus_no, FM_6609_BN_FF_VRM_2);
		break;
	case PSU_ID_VRM3:
		onlp_pmbus_vrm3_info_get(p);
		break;
	default:
		break;
    }		
	return 0;
}
	
int
onlp_psui_info_get(onlp_oid_t id, onlp_psu_info_t* info)
{
    int data = 0x0/*, val_1 = 0x0*/;
    int pid;
	//int vout_mode;
    uint8_t psu_addr;
    uint8_t channel;
    //uint8_t buffer[ONLP_CONFIG_INFO_STR_MAX];
    //int rv;
    onlp_psu_info_t *p = NULL;
    int is_present;
	int bus_no;
	bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + FM_6609_BN_FF_I2C_MUX_CH1;

    pid = ONLP_OID_ID_GET(id);
	if(pid > PSU_ID_VRM3)
        return ONLP_STATUS_E_INVALID;

    data  = onlp_i2c_readb(bus_no, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_PSR, ONLP_I2C_F_FORCE);

    p = &psu_info[pid];

    switch (pid) {
    case PSU_ID_PSUA:
        channel = FM_6609_BN_FF_I2C_MUX_CH0;
        psu_addr = FM_6609_BN_FF_PSU_A;
        is_present = (((data & 0x08) >> 3) == 0) ? 1 : 0; /* 0000 1000 ==> check bit_3 equals 0 or not! */
        break;
    case PSU_ID_PSUB:
        channel = FM_6609_BN_FF_I2C_MUX_CH1;
        psu_addr = FM_6609_BN_FF_PSU_B;
        is_present = (((data & 0x04) >> 2) == 0) ? 1 : 0; /* 0000 0100 ==> check bit_2 equals 0 or not! */
        break;
	case PSU_ID_VRM1:
	case PSU_ID_VRM2:
	case PSU_ID_VRM3:
		is_present = 1;
		onlp_psui_vrm_info_get(p, pid);
	    memcpy((void *__restrict )info, (void *__restrict )p, sizeof(onlp_psu_info_t));
	    return ONLP_STATUS_OK;
    default:
        return ONLP_STATUS_E_INVALID;
        break;
    }

    if(is_present == 0) {	/* Means PSU doesn't installed */
        p->status = ONLP_PSU_STATUS_UNPLUGGED;
        goto end;
    }

	bus_no = FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + channel;
	
    data  = onlp_i2c_readw(bus_no, psu_addr, PMNUS_STATUS_WORD_REG, ONLP_I2C_F_FORCE);
	/* check fault / warning case, include following case:  
	    TEMPERATURE FAULT OR WARNING, IOUT_OC_FAULT, VOUT_OV_FAULT, VIN_UV_FAULT
	    UNIT IS OFF, UNIT WAS BUSY, INPUT FAULT OR WARNING, IOUT/POUT FAULT OR WARNING
	    VOUT FAULT OR WARNING, UNKNOWN FAULT OR WARNING, FAN FAULT OR WARNING
	*/
    if (data & 0xe5fc)
    {
        p->status = ONLP_PSU_STATUS_FAILED;
        goto end;
    }
	
    /* PSU is present. */
    p->status = ONLP_PSU_STATUS_PRESENT;
    p->caps |= ONLP_PSU_CAPS_AC;

    /* READ VIN */
	onlp_get_pmbus_vin_info(p, bus_no, psu_addr);
    
    /* READ IIN */
	onlp_get_pmbus_iin_info(p, bus_no, psu_addr);

    /* VOUT_MODE */
	onlp_get_vout_info(p, bus_no, psu_addr);
	
    /* READ IOUT */
	onlp_get_pmbus_iout_info(p, bus_no, psu_addr);
	
    /* READ PIN */
	onlp_get_pmbus_pin_info(p, bus_no, psu_addr);
	
    /* READ POUT */
	onlp_get_pmbus_pout_info(p, bus_no, psu_addr);
	
    /* READ mfr_model  */
	onlp_get_pmbus_mfr_model_info(p, bus_no, psu_addr);
	
    /* READ mfr_serial  */
	onlp_get_pmbus_mfr_serial_info(p, bus_no, psu_addr);
end:
    /* Sync local info to incoming pointer */
    memcpy((void *__restrict )info, (void *__restrict )p, sizeof(onlp_psu_info_t));
    return ONLP_STATUS_OK;
}
