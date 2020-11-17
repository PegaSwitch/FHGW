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
#include <onlp/platformi/psui.h>
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
    return "x86-64-pegatron-fm-6609-bn-ff-r0";
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

	bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + FM_6609_BN_FF_I2C_MUX_CH3;
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
    for (i=1; i <= (CHASSIS_PSU_COUNT+CHASSIS_VRM_COUNT); i++)
    {
        *e++ = ONLP_PSU_ID_CREATE(i);
    }

    /* LEDs Item */
    for (i=1; i <= CHASSIS_LED_COUNT; i++)
    {
        *e++ = ONLP_LED_ID_CREATE(i);
    }

     /* THERMALs Item */
    for (i=1; i<= CHASSIS_THERMAL_COUNT; i++)
    {
        *e++ = ONLP_THERMAL_ID_CREATE(i);
    }

    /* Fans Item */
    for (i=1; i<= CHASSIS_FAN_COUNT; i++)
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
    int cpld_b_ver=0;
    int cpld_d_ver=0;
	int bus_no = 0;
	bus_no = FM_6609_BN_FF_I2C_MUX2_BUS_START_FROM + FM_6609_BN_FF_I2C_MUX_CH1;
	data = onlp_i2c_readb(bus_no, FM_6609_BN_FF_CPLD_B, 0x00, ONLP_I2C_F_FORCE);
    cpld_b_ver = data & 0x0F;
    data = onlp_i2c_readb(FM_6609_BN_FF_I2C_BUS1, FM_6609_BN_FF_CPLD_D, 0x00, ONLP_I2C_F_FORCE);
    cpld_d_ver = data & 0x0F;
    pi->cpld_versions = aim_fstrdup("%d.%d", cpld_b_ver, cpld_d_ver);
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
static int start_led_manual_mode(int enable)
{		
	FILE *fp;
	char buf[32]={0};
	char *file = "/var/led_manual";
	
	fp = fopen(file, "w");
	if(fp) {
		sprintf(buf, "%d", enable);
		fwrite(buf, 1, sizeof(buf), fp);
		fclose(fp);
	}
	return 0;
}

static int get_led_manual_mode_state(void)
{
	FILE *fp;
	int enable = 0;
	char buf[32]={0};
	char *file = "/var/led_manual";
	fp = fopen(file, "r");
	if(fp) {
		fread(buf, sizeof(buf), 1, fp);
		enable = atoi(buf);
		fclose(fp);
	}
	return enable;
}

int onlp_sysi_platform_manage_leds(void)
{
    int i;
    onlp_fan_info_t info;
	onlp_psu_info_t psuinfo;
    int fan_id;
	int fail_fans = 0;
	int psu_fail = 0;
	int psu_id;

	//Into led test mode, ignore led status polling task.
	if(get_led_manual_mode_state())
		return 0;
    for (i = 0; i <= CHASSIS_FAN_COUNT; i++) {
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
		onlp_ledi_mode_set(LED_OID_FAN_STATUS, ONLP_LED_MODE_GREEN);
	else
		onlp_ledi_mode_set(LED_OID_FAN_STATUS, ONLP_LED_MODE_ORANGE);

	// config psu status led after check psu current status.
    for (i = 0; i <= CHASSIS_PSU_COUNT; i++) {
        psu_id= ONLP_PSU_ID_CREATE(i);
        memset(&psuinfo, 0, sizeof(onlp_psu_info_t));
		onlp_psui_info_get(psu_id, &psuinfo);
		if(psuinfo.status == ONLP_PSU_STATUS_FAILED)
			psu_fail++;
    }
	if(psu_fail == 0)
		onlp_ledi_mode_set(LED_OID_POWER_STATUS, ONLP_LED_MODE_GREEN);
	else 			
		onlp_ledi_mode_set(LED_OID_POWER_STATUS, ONLP_LED_MODE_ORANGE_BLINKING);
    return 0;
}

/**
 * @brief Builtin platform debug tool.
 */
int onlp_sysi_debug(aim_pvs_t* pvs, int argc, char** argv)
{
	if(argc == 0) {		
        printf("\nUsage: onlpdump debug [OPTION]\n");
        printf("led ctrl_test            : into led control test mode.\n");
        printf("led finish_test          : Finish led control test mode.\n");
		return 0;
	} else if(argc == 2) {
		if(!strcmp(argv[0], "led")) {
			if(!strcmp(argv[1], "ctrl_test")) {
				printf("Start led control test mode.\n");
				start_led_manual_mode(1);
			} else if(!strcmp(argv[1], "finish_test")) {	
				printf("Finish led control test mode.\n");
				start_led_manual_mode(0);
			} else
				;
		}
	} else
		;
	return 0;
}

