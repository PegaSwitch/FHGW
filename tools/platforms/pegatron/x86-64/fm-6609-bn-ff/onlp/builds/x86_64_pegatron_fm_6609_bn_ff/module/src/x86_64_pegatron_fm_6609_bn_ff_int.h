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

#ifndef __X86_64_PEGATRON_FM_6609_BN_FF_INT_H__
#define __X86_64_PEGATRON_FM_6609_BN_FF_INT_H__

#include <x86_64_pegatron_fm_6609_bn_ff/x86_64_pegatron_fm_6609_bn_ff_config.h>

/** psu id **/
typedef enum psu_id_e {
    PSU_ID_PSUA = 1,
    PSU_ID_PSUB,
    PSU_ID_END,
} psu_id_t;

/** psu_oid */
typedef enum psu_oid_e {
    PSU_OID_PSUA = ONLP_PSU_ID_CREATE(PSU_ID_PSUA),
    PSU_OID_PSUB = ONLP_PSU_ID_CREATE(PSU_ID_PSUB),
} psu_oid_t;

/** led_id */
typedef enum led_id_e {
    LED_ID_SYSTEM_STATUS = 1,
    LED_ID_FAN_STATUS,
    LED_ID_POWER_STATUS,
    LED_ID_SYSTEM_LOCATOR,
    LED_ID_END,
} led_id_t;

/** led_oid */
typedef enum led_oid_e {
    LED_OID_SYSTEM_STATUS = ONLP_LED_ID_CREATE(LED_ID_SYSTEM_STATUS),
    LED_OID_FAN_STATUS = ONLP_LED_ID_CREATE(LED_ID_FAN_STATUS),
    LED_OID_POWER_STATUS = ONLP_LED_ID_CREATE(LED_ID_POWER_STATUS),
    LED_OID_SYSTEM_LOCATOR = ONLP_LED_ID_CREATE(LED_ID_SYSTEM_LOCATOR),
} led_oid_t;

/** fan_id */
typedef enum fan_id_e {
    FAN_ID_FANA_OUTLET = 1,
    FAN_ID_FANA_INLET,
    FAN_ID_FANB_OUTLET,
    FAN_ID_FANB_INLET,
    FAN_ID_FANC_OUTLET,
    FAN_ID_FANC_INLET,
    FAN_ID_FAND_OUTLET,
    FAN_ID_FAND_INLET,
    FAN_ID_FANE_OUTLET,
    FAN_ID_FANE_INLET,
    FAN_ID_FAN_PSUA,
    FAN_ID_FAN_PSUB,
    FAN_ID_END,
} fan_id_t;

/** fan_oid */
typedef enum fan_oid_e {
    FAN_OID_FANA_OUTLET = ONLP_FAN_ID_CREATE(FAN_ID_FANA_OUTLET),
    FAN_OID_FANA_INLET = ONLP_FAN_ID_CREATE(FAN_ID_FANA_INLET),
    FAN_OID_FANB_OUTLET = ONLP_FAN_ID_CREATE(FAN_ID_FANB_OUTLET),
    FAN_OID_FANB_INLET = ONLP_FAN_ID_CREATE(FAN_ID_FANB_INLET),
    FAN_OID_FANC_OUTLET = ONLP_FAN_ID_CREATE(FAN_ID_FANC_OUTLET),
    FAN_OID_FANC_INLET = ONLP_FAN_ID_CREATE(FAN_ID_FANC_INLET),
    FAN_OID_FAND_OUTLET = ONLP_FAN_ID_CREATE(FAN_ID_FAND_OUTLET),
    FAN_OID_FAND_INLET = ONLP_FAN_ID_CREATE(FAN_ID_FAND_INLET),
    FAN_OID_FANE_OUTLET = ONLP_FAN_ID_CREATE(FAN_ID_FANE_OUTLET),
    FAN_OID_FANE_INLET = ONLP_FAN_ID_CREATE(FAN_ID_FANE_INLET),
    FAN_OID_FAN_PSUA = ONLP_FAN_ID_CREATE(FAN_ID_FAN_PSUA),
    FAN_OID_FAN_PSUB = ONLP_FAN_ID_CREATE(FAN_ID_FAN_PSUB),
} fan_oid_t;

/** thermail_id */
typedef enum thermail_id_e {
    THERMAL_ID_ON_MAIN_BROAD_1 = 1,
    THERMAL_ID_ON_MAIN_BROAD_2,
    THERMAL_ID_ON_MAIN_BROAD_3,
    THERMAL_ID_ON_NPU_BROAD,
    THERMAL_ID_ON_PSUA_1,
    THERMAL_ID_ON_PSUA_2,
    THERMAL_ID_ON_PSUA_3,
    THERMAL_ID_ON_PSUB_1,
    THERMAL_ID_ON_PSUB_2,
    THERMAL_ID_ON_PSUB_3,
    THERMAL_ID_END,
} thermail_id_t;

/** thermail_oid */
typedef enum thermail_oid_e {
    THERMAL_OID_ON_MAIN_BROAD_1 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_MAIN_BROAD_1),
    THERMAL_OID_ON_MAIN_BROAD_2 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_MAIN_BROAD_2),
	THERMAL_OID_ON_MAIN_BROAD_3 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_MAIN_BROAD_3),
	THERMAL_OID_ON_NPU_BROAD = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_NPU_BROAD),
    THERMAL_OID_ON_PSUA_1 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_PSUA_1),
    THERMAL_OID_ON_PSUA_2 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_PSUA_2),
    THERMAL_OID_ON_PSUA_3 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_PSUA_3),
    THERMAL_OID_ON_PSUB_1 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_PSUB_1),
    THERMAL_OID_ON_PSUB_2 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_PSUB_2),
    THERMAL_OID_ON_PSUB_3 = ONLP_THERMAL_ID_CREATE(THERMAL_ID_ON_PSUB_3),
} thermail_oid_t;

#endif /* X86_64_PEGATRON_FM_6609_BN_FF */
