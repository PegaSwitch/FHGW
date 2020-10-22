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
#include <onlp/platformi/sysi.h>
#include <onlp/platformi/fani.h>
#include <onlp/platformi/ledi.h>
#include <onlp/platformi/thermali.h>
#include <onlplib/crc32.h>
#include "x86_64_pegatron_fm_6609_bn_ff_int.h"
#include "x86_64_pegatron_fm_6609_bn_ff_log.h"
#include <x86_64_pegatron_fm_6609_bn_ff/x86_64_pegatron_fm_6609_bn_ff_i2c_table.h>
#include <onlplib/i2c.h>

#define SW_VERSION "0.0.0.1"
/**
 * @brief Return the name of the the platform implementation.
 * @notes This will be called PRIOR to any other calls into the
 * platform driver, including the sysi_init() function below.
 *
 * The platform implementation name should match the current
 * ONLP platform name.
 *
 * IF the platform implementation name equals the current platform name,
 * initialization will continue.
 *
 * If the platform implementation name does not match, the following will be
 * attempted:
 *
 *    onlp_sysi_platform_set(current_platform_name);
 * If this call is successful, initialization will continue.
 * If this call fails, platform initialization will abort().
 *
 * The onlp_sysi_platform_set() function is optional.
 * The onlp_sysi_platform_get() is not optional.
 */
const char *onlp_sysi_platform_get(void)
{
    return "x86-64-pegatron-fm-6256-bn-f-r0";
}

/**
 * @brief Initialize the system platform subsystem.
 */
int onlp_sysi_init(void)
{

    return ONLP_STATUS_OK;
}

/**
 * @brief Return the raw contents of the ONIE system eeprom.
 * @param data [out] Receives the data pointer to the ONIE data.
 * @param size [out] Receives the size of the data (if available).
 * @notes This function is only necessary if you cannot provide
 * the physical base address as per onlp_sysi_onie_data_phys_addr_get().
 */
int onlp_sysi_onie_data_get(uint8_t** data, int* size)
{
    uint8_t* rdata = aim_zmalloc(256);
    uint8_t d;
    int i=0;
	int bus_no = 0;

	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_3;
    do {
        //if(i++ > 0xff)
        //  break;
        d = onlp_i2c_readb(bus_no, 0x54, 0x0+i, ONLP_I2C_F_FORCE);
		if(d < 0) {
			break;
		}
        if(d != 0xff) {
            *(rdata+i) = d;
            i++;
        }
    } while (d != 0xff );
    *data = rdata;
    return 0;
}

/**
 * @brief Free the data returned by onlp_sys_onie_data_get()
 * @param data The data pointer.
 * @notes If onlp_sysi_onie_data_get() is called to retreive the
 * contents of the ONIE system eeprom then this function
 * will be called to perform any cleanup that may be necessary
 * after the data has been used.
 */
void onlp_sysi_onie_data_free(uint8_t* data)
{
    aim_free(data);
}

/**
 * @brief This function returns the root oid list for the platform.
 * @param table [out] Receives the table.
 * @param max The maximum number of entries you can fill.
 */
int onlp_sysi_oids_get(onlp_oid_t* table, int max)
{
    onlp_oid_t* e = table;
    memset(table, 0, max*sizeof(onlp_oid_t));
    int i;

    /* PSUs Item */
    for (i=1; i < PSU_ID_END; i++)
    {
        *e++ = ONLP_PSU_ID_CREATE(i);
    }

    /* LEDs Item */
    for (i=1; i < LED_ID_END; i++)
    {
        *e++ = ONLP_LED_ID_CREATE(i);
    }

     /* THERMALs Item */
    for (i=1; i< THERMAL_ID_END; i++)
    {
        *e++ = ONLP_THERMAL_ID_CREATE(i);
    }

    /* Fans Item */
    for (i=1; i< FAN_ID_END; i++)
    {
        *e++ = ONLP_FAN_ID_CREATE(i);
    }

    return 0;
}

/**
 * @brief Return custom platform information.
 */
int onlp_sysi_platform_info_get(onlp_platform_info_t* pi)
{
    int data;
    int cpld_a_ver=0;
    int cpld_b_ver=0;
    int cpld_c_ver=0;
    int cpld_d_ver=0;
	int bus_no = 0;

	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_0;
    data = onlp_i2c_readb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_A, 0x00, ONLP_I2C_F_FORCE);
    cpld_a_ver = data & 0x0F;	
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_1;
	data = onlp_i2c_readb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_B, 0x00, ONLP_I2C_F_FORCE);
    cpld_b_ver = data & 0x0F;	
	bus_no = PEGATRON_FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + PEGATRON_FM_6609_BN_FF_I2C_MUX_CHANNEL_2;
	data = onlp_i2c_readb(bus_no, PEGATRON_FM_6609_BN_FF_I2C_CPLD_C, 0x00, ONLP_I2C_F_FORCE);
    cpld_c_ver = data & 0x0F;
    data = onlp_i2c_readb(PEGATRON_FM_6609_BN_FF_I2C_BUS1, PEGATRON_FM_6609_BN_FF_I2C_CPLD_D, 0x00, ONLP_I2C_F_FORCE);
    cpld_d_ver = data & 0x0F;
    pi->cpld_versions = aim_fstrdup("%d.%d.%d.%d", cpld_a_ver, cpld_b_ver, cpld_c_ver, cpld_d_ver);
    pi->other_versions = aim_fstrdup("%s", SW_VERSION);
    return ONLP_STATUS_OK;
}

/**
 * @brief Friee a custom platform information structure.
 */
void onlp_sysi_platform_info_free(onlp_platform_info_t* pi)
{
    aim_free(pi->cpld_versions);
    aim_free(pi->other_versions);
}
#if 0 
int onlp_sysi_platform_manage_fans(void)
{
    int i;
    onlp_thermal_info_t t;
    int thermal_id;

    for (i = THERMAL_ID_ON_MAIN_BROAD_1; i <= THERMAL_ID_ON_MAIN_BROAD_3; i++) {
        thermal_id = ONLP_FAN_ID_CREATE(i);
        memset(&t, 0, sizeof(onlp_thermal_info_t));	
        if(onlp_thermali_info_get(thermal_id, &t) != ONLP_STATUS_OK) {
            onlp_fani_percentage_set(FAN_ID_FANA_OUTLET, 100);
        } else {
            if(t.mcelsius > t.thresholds.warning) {
                onlp_fani_percentage_set(FAN_ID_FANA_OUTLET, 75);
            } else if(t.mcelsius > t.thresholds.error) {
                onlp_fani_percentage_set(FAN_ID_FANA_OUTLET, 90);
            } else if(t.mcelsius > t.thresholds.shutdown) {
                onlp_fani_percentage_set(FAN_ID_FANA_OUTLET, 100);
            } else {
                onlp_fani_percentage_set(FAN_ID_FANA_OUTLET, 50);
            }
        }
    }
    return 0;
}
#endif

int onlp_sysi_platform_manage_leds(void)
{
    int i;
    onlp_fan_info_t info;
    int fan_id;
	int fail_fans = 0;

    for (i = 0; i <= FAN_ID_FANE_INLET; i++) {
        fan_id = ONLP_FAN_ID_CREATE(i);
        memset(&info, 0, sizeof(onlp_fan_info_t));
        if(onlp_fani_info_get(fan_id, &info) != ONLP_STATUS_OK) {
                /* operate corresponding LED */
                fail_fans++;
        } else {
                /* operate corresponding LED */
                if(info.rpm < 500) {
                    fail_fans++;
                }
        }
    }
	if(fail_fans == 0)
		onlp_ledi_mode_set(LED_ID_FAN_STATUS, ONLP_LED_MODE_GREEN);
	else {	
		if(fail_fans == 1)
			onlp_ledi_mode_set(LED_ID_FAN_STATUS, ONLP_LED_MODE_ORANGE);
		else if(fail_fans > 2) {
			//FIXME: should indicate red solid, but current led doesn't support red solid.
			onlp_ledi_mode_set(LED_ID_FAN_STATUS, ONLP_LED_MODE_ORANGE);
		}
	}
    return 0;
}

