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
 * Thermal Sensor Platform Implementation.
 *
 ***********************************************************/
#include <math.h>
#include <onlp/platformi/thermali.h>
#include "x86_64_pegatron_fm_6609_bn_ff_log.h"
#include "x86_64_pegatron_fm_6609_bn_ff_int.h"
#include <onlplib/i2c.h>
#include <x86_64_pegatron_fm_6609_bn_ff/x86_64_pegatron_fm_6609_bn_ff_i2c_table.h>

static onlp_thermal_info_t thermal_info[] = {
    { }, /* Not used */
    { { THERMAL_OID_ON_MAIN_BROAD_1,  "LM75BD / Ambient MAC side",  0},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_ALL, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_MAIN_BROAD_2,  "LM75BD / Ambient MAC",  0},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_ALL, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_MAIN_BROAD_3,  "LM75BD / Ambient FAN",  0},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_ALL, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_NPU_BROAD,  "LM75BD / Ambient NPU",  0},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_ALL, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_PSUA_1,  "PSU-A Thermal 1", PSU_OID_PSUA},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_PSUA_2,  "PSU-A Thermal 2", PSU_OID_PSUA},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_PSUA_3,  "PSU-A Thermal 3", PSU_OID_PSUA},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_PSUB_1,  "PSU-B Thermal 1", PSU_OID_PSUB},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_PSUB_2,  "PSU-B Thermal 2", PSU_OID_PSUB},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_PSUB_3,  "PSU-B Thermal 3", PSU_OID_PSUB},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_VRM1_1,  "TPS53679(0x60) Thermal", PSU_OID_VRM1},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_VRM2_1,  "TPS53679(0x63) Thermal", PSU_OID_VRM2},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
    { { THERMAL_OID_ON_VRM3_1,  "TPS53679(0x64) Thermal", PSU_OID_VRM3},
        ONLP_THERMAL_STATUS_PRESENT,
        ONLP_THERMAL_CAPS_GET_TEMPERATURE, 0, ONLP_THERMAL_THRESHOLD_INIT_DEFAULTS
    },
};

int
Get_Sys_Thermal_Status(onlp_thermal_info_t* info, int tid)
{
    int data = 0x0;
    uint8_t offset;
	int rv = ONLP_STATUS_OK;
	int bus_no;
	int reg_num;
	
	bus_no = FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + FM_6609_BN_FF_I2C_MUX_CH3;
	reg_num = FM_6609_BN_FF_MCU;
    switch (tid) {
    case THERMAL_ID_ON_MAIN_BROAD_1:
        offset = 0x70;
        break;
    case THERMAL_ID_ON_MAIN_BROAD_2:
        offset = 0x71;
        break;
	//FIXME	
    case THERMAL_ID_ON_MAIN_BROAD_3:	
        offset = 0x72;
        break;
	case THERMAL_ID_ON_NPU_BROAD:
		bus_no = FM_6609_BN_FF_I2C_BUS1;
		reg_num = FM_6609_BN_FF_LM_THERMAL;	
		offset = 0x00;
		break;
    default:
        rv = ONLP_STATUS_E_INVALID;
		goto error;
        break;
    }

    //i2c MUX Sel to main board HW-Monitor IC 
    data  = onlp_i2c_readb(bus_no, reg_num, offset, ONLP_I2C_F_FORCE);
	if(tid == THERMAL_ID_ON_NPU_BROAD) {
	    if (data & 0x80)
	        info->mcelsius=(0-((~data & 0x7f) + 0x1))*1000; //do 2's complement
	    else
	        info->mcelsius=data*1000;
	} else
		info->mcelsius=data*1000;
error:	
    return rv;
}

static int process_thermal_rawdata(onlp_thermal_info_t* info, int raw_data)
{
    int val_1 = 0x0, val_2 = 0x0;

    val_1 = (raw_data & 0xf800) >> 11;
    val_2 = raw_data & 0x07ff;
    if (val_1 & 0x10) {
        val_1 = ((~val_1) & 0x1f) + 0x1;
        val_1 = val_1 * -1;
    }
    info->mcelsius = (int)((pow(2, val_1)*1000)*val_2);
	return 0;

}

static int get_VRM_thermal_rawdata(int bus_no, int address, int reg_num)
{
	int data;
	onlp_i2c_writew(bus_no, address, PMBUS_PAGE_REG, 0xFF, ONLP_I2C_F_FORCE);
	data = onlp_i2c_readw(bus_no, address, reg_num, ONLP_I2C_F_FORCE);
	return data;
}

static int get_VRM_thermal(onlp_thermal_info_t* info, int bus_no, int address, int reg_num)
{
    int data=0;
	data = get_VRM_thermal_rawdata(bus_no, address, reg_num);
	process_thermal_rawdata(info, data);
	return 0;
}

int Get_VRM_Thermal_Status(onlp_thermal_info_t* info, int tid)
{	
	int bus_no;
	bus_no = FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + FM_6609_BN_FF_I2C_MUX_CH2;
	switch (tid) {
	case THERMAL_ID_ON_VRM1_1:
		get_VRM_thermal(info, bus_no, FM_6609_BN_FF_VRM_1, PMBUS_TEMPERATUR1_REG);
		break;
    case THERMAL_ID_ON_VRM2_1:
		bus_no = FM_6609_BN_FF_I2C_BUS1;
		get_VRM_thermal(info, bus_no, FM_6609_BN_FF_VRM_2, PMBUS_TEMPERATUR1_REG);
		break;
    case THERMAL_ID_ON_VRM3_1:
		bus_no = FM_6609_BN_FF_I2C_BUS1;
		get_VRM_thermal(info, bus_no, FM_6609_BN_FF_VRM_3, PMBUS_TEMPERATUR1_REG);
		break;
	default:
		break;
	}
	return 0;
}

int
Get_Power_Thermal_Status(onlp_thermal_info_t* info, int tid)
{
    int rv = 0, data = 0x0;
    uint8_t psu_addr;
    uint8_t channel;
    uint8_t offset;
    int is_present;
	int bus_no;
	bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + FM_6609_BN_FF_I2C_MUX_CH1;
	
    data  = onlp_i2c_readb(bus_no, FM_6609_BN_FF_CPLD_B, FM_6609_BN_FF_CPLD_B_PSR, ONLP_I2C_F_FORCE);
    switch (tid) {
    case THERMAL_ID_ON_PSUA_1:
        channel = FM_6609_BN_FF_I2C_MUX_CH0;
        psu_addr = FM_6609_BN_FF_PSU_A;
        offset = PMBUS_TEMPERATUR1_REG;
        break;
    case THERMAL_ID_ON_PSUA_2:
        channel = FM_6609_BN_FF_I2C_MUX_CH0;
        psu_addr = FM_6609_BN_FF_PSU_A;
        offset = PMBUS_TEMPERATUR2_REG;
        break;
    case THERMAL_ID_ON_PSUA_3:
        channel = FM_6609_BN_FF_I2C_MUX_CH0;
        psu_addr = FM_6609_BN_FF_PSU_A;
        offset = PMBUS_TEMPERATUR3_REG;
        break;
    case THERMAL_ID_ON_PSUB_1:
        channel = FM_6609_BN_FF_I2C_MUX_CH1;
        psu_addr = FM_6609_BN_FF_PSU_B;
        offset = PMBUS_TEMPERATUR1_REG;
        break;
    case THERMAL_ID_ON_PSUB_2:
        channel = FM_6609_BN_FF_I2C_MUX_CH1;
        psu_addr = FM_6609_BN_FF_PSU_B;
        offset = PMBUS_TEMPERATUR2_REG;
        break;
    case THERMAL_ID_ON_PSUB_3:
        channel = FM_6609_BN_FF_I2C_MUX_CH1;
        psu_addr = FM_6609_BN_FF_PSU_B;
        offset = PMBUS_TEMPERATUR3_REG;
        break;
    default:
        return ONLP_STATUS_E_INVALID;
        break;
    }
	if((tid == THERMAL_ID_ON_PSUA_1) || 
	   (tid == THERMAL_ID_ON_PSUA_2) || 
	   (tid == THERMAL_ID_ON_PSUA_3)) 
		is_present = (((data & 0x08) >> 3) == 0) ? 1 : 0; /* 0000 1000 ==> check bit_3 equals 0 or not! */
	else			
		is_present = (((data & 0x04) >> 2) == 0) ? 1 : 0; /* 0000 0100 ==> check bit_2 equals 0 or not! */	
    if(is_present == 0) {	/* Means PSU doesn't installed */
        info->status = ONLP_THERMAL_STATUS_FAILED;
        rv = ONLP_STATUS_E_INTERNAL;
        goto error;
    }
    //i2c MUX Sel to main board HW-Monitor IC     
	bus_no = FM_6609_BN_FF_I2C_MUX1_BUS_START_FROM + channel;
    data  = onlp_i2c_readw(bus_no, psu_addr, PMBUS_VOLTAGE_IN_REG, ONLP_I2C_F_FORCE);
    if (data <= 0) {
        info->status = ONLP_THERMAL_STATUS_FAILED;
        rv = ONLP_STATUS_E_INTERNAL;
        goto error;
    }

    rv = ONLP_STATUS_OK;
    data  = onlp_i2c_readw(bus_no, psu_addr, offset, ONLP_I2C_F_FORCE);
	process_thermal_rawdata(info, data);
error:
    return rv;
}

int
onlp_thermali_init(void)
{
	return ONLP_STATUS_OK;
}

static onlp_thermal_info_t *_thermali_info_get(onlp_oid_t id)
{
    int tid = ONLP_OID_ID_GET(id);
    onlp_thermal_info_t *info = NULL;
	if(tid < THERMAL_ID_END)
		info = &thermal_info[tid];
    return info;
}

/**
 * @brief Get the information for the given thermal OID.
 * @param id The Thermal OID
 * @param rv [out] Receives the thermal information.
 */
int onlp_thermali_info_get(onlp_oid_t id, onlp_thermal_info_t* rv)
{
    onlp_thermal_info_t *t = _thermali_info_get(id);
    onlp_status_t ret = ONLP_STATUS_OK;
    int tid;

    if(t) {
        tid = ONLP_OID_ID_GET(id);
        if (tid <= THERMAL_ID_ON_NPU_BROAD) {
			ret = Get_Sys_Thermal_Status(t, tid);
        } else if ((tid >= THERMAL_ID_ON_PSUA_1) && (tid <= THERMAL_ID_ON_PSUB_3)){
			ret = Get_Power_Thermal_Status(t, tid);
        } else {
			ret = Get_VRM_Thermal_Status(t, tid);
        }
        memcpy((void *__restrict )rv, (void *__restrict )t, sizeof(onlp_thermal_info_t));
    } else {
        rv = NULL;
        ret = ONLP_STATUS_E_INVALID;
    }
    return ret;
}

/**
 * @brief Retrieve the thermal's operational status.
 * @param id The thermal oid.
 * @param rv [out] Receives the operational status.
 */
int onlp_thermali_status_get(onlp_oid_t id, uint32_t* rv)
{
    onlp_thermal_info_t *info = _thermali_info_get(id);
    onlp_status_t ret = ONLP_STATUS_OK;

    if(info)
        *rv = info->status;
    else {
        *rv = ONLP_THERMAL_STATUS_FAILED;
        ret = ONLP_STATUS_E_INVALID;
    }
    return ret;
}

/**
 * @brief Retrieve the thermal's oid header.
 * @param id The thermal oid.
 * @param rv [out] Receives the header.
 */
int onlp_thermali_hdr_get(onlp_oid_t id, onlp_oid_hdr_t* rv)
{
    onlp_thermal_info_t *info = _thermali_info_get(id);
    onlp_status_t ret = ONLP_STATUS_OK;

    if(info)
        memcpy((void *__restrict )rv, (void *__restrict )&info->hdr, sizeof(onlp_oid_hdr_t));
    else {
        rv = NULL;
        ret = ONLP_STATUS_E_INVALID;
    }
    return ret;
}

