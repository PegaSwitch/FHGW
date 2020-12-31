#!/bin/bash

# Purpose : This script arrange the diagnostic test for EDVT and PT.

# Test Mode Description
# 1:EDVT
#   4C Component Test
#   4C Internal Traffic Test (with DAC/fiber cable)
#   4C Component + Internal Traffic Test
#   4C Component + External Traffic Test
# 2:PT
#   Fan Test
#   Storage Test
#   Internal Traffic Test (with loopback module)
# 3:THERMAL
#   Modules' watt Setting
#   CPU Loading Gain
#   Component Test
#   Internal Traffic Flooding Test
# 4:EMC
#   Component Test (only need USB)
#   OOB ping Test
#   Internal Traffic Test ( = burn-in )
# 5:QTR
#   External Traffic Test
# 6:SAFETY
#   Modules' watt Setting
#   CPU Loading Gain
#   Component Test
#   Internal Traffic Test ( = burn-in )
# 7:FW_REGRESSION
#   MCU FW upgrade + CPLD FW upgrade + (SPI FW upgrade) + Internal Traffic Test (with loopback module)


source /home/root/mfg/mfg_sources/platform_detect.sh

# Following are parameters definition.
{
    ## This is for some platform's MB didn't support voltage control through dynamic software commands.
    ## EE need rework to set +-5% voltage, so keep voltage +/-5% setting (every 12hr).
    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        EDVT_REQUEST_REMAIN_VOLTAGE_SETTING=$TURE
    else
        EDVT_REQUEST_REMAIN_VOLTAGE_SETTING=$FALSE
    fi

    # Parameter for Debug
    DBG_MODE=0
    DBG_PRINT_PARSE_USER_CMD=0
    DBG_PRINT_PARSE_CONF=0
    DBG_SYS_LED_STATUS=0

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    if (( $DBG_MODE == $FALSE )); then
        if [ ! -d "$LOG_PATH_HOME" ]; then
            mkdir "$LOG_PATH_HOME"
        fi
    fi

    # File Name Define
    DIAG_HW_MONITOR_LOG_NAME=${LOG_PATH_HWMONITOR}/hw_monitor_1.log
    DIAG_PT_TEST_RESULT_LOG_NAME=${LOG_PATH_HOME}/diag_burn_in_result.log

    DIAG_FW_REGRESSION_ROUNDCHECK_FILE="$LOG_PATH_HOME/roundCheck"

    DIAG_FAN_TEST_RESULT=$PASS
    DIAG_STORAGE_TEST_RESULT=$PASS
    DIAG_TRAFFIC_TEST_RESULT=$PASS      # Only use under PT test mode.
    DIAG_I2C_TEST_RESULT=$PASS          # Only use under PT test mode.

    DIAG_BURNIN_RESULT_NOTE=${LOG_PATH_HOME}/"burninResult"    ## For note burnin result to light LED quickly.

    # Diagnostic Test Result Flag (Summary of all burn-in round result.)
    DIAG_TEST_RESULT=$PASS

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # ***** Power Cycle / Burn-In ***** #

    # For EDVT
    DIAG_EDVT_TEST_SET="off"            # on / off
    DIAG_EDVT_POWER_CYCLE_NUM=4         # number of power cycle for 4C test

    # For PT
    DIAG_BURN_IN_SET="off"              # on / off
    DIAG_PT_POWER_CYCLE_NUM=1           # number of power cycle for burn-in test
    DIAG_BURN_IN_CYCLE_NUM=1            # number of burn-in cycle
    DIAG_CURRENT_POWER_CYCLE_ROUND=1    # current power cycle round

    # For Thermal
    DIAG_THERMAL_TEST_SET="off"         # on / off
    # For EMC
    DIAG_EMC_TEST_SET="off"             # on / off
    # For Safety
    DIAG_SAFETY_TEST_SET="off"          # on / off
    # For QTR
    DIAG_QTR_TEST_SET="off"             # on / off
    # For FW Regression test
    DIAG_FW_UPGRADE_TEST_SET="off"      # on / off

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # ***** EDVT Current Select Test (For EDVT Only) ***** #

    # Selection :
    # 1:4C Component Test
    # 2:4C Internal Traffic Test
    # 3:4C Component + Internal Traffic Test
    # 4:4C Component + External Traffic Test
    # 5:External Traffic Test

    DIAG_EDVT_SEL_TEST="4C Component + External Traffic Test"

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # ***** Fan Test (For PT Only) ***** #

    DIAG_FAN_PWM_BREAK_POINT=10         # (unit : percent)
    DIAG_FAN_HIGH_SPEED_RPM_TLR=15      # (unit : percent)
    DIAG_FAN_LOW_SPEED_RPM_TLR=0x8c     # (unit : r.p.m)  0x8c=500 rpm . Reference: MB MCU register table - '0x1c'

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # ***** 4C Component Test ***** #

    DIAG_EDVT_TEST_TIME=1                           # each component test execution time (unit : min)
                                                    # need to transfer to second for component test

    # Storage Test Default Parameter
    DIAG_STORAGE_TEST_MODE="parallel"               # 1:parallel(for EDVT) / 2:sequential(for PT)
    DIAG_STORAGE_TEST_SIZE=128                      # 64 / 128 / 256 / 512 / 1024 (unit : Mega bytes)
    DIAG_STORAGE_TEST_DEVICE="DRAM-eMMC-USB-SSD-SPI"    # 1:DRAM, eMMC / 2:DRAM, eMMC, USB / 3:DRAM, eMMC, USB, SSD / 4:DRAM, eMMC, USB, SSD, SPI
    DIAG_STORAGE_TEST_CNS_OUT="no"                  # yes / no < can only set by programmer >

    # OOB Test Default Parameter
    DIAG_OOB_TEST_DUT_IP="192.168.1.1"              # for OOB(SGMII) test DUT IP
    DIAG_OOB_TEST_TARGET_IP="192.168.1.2"           # for OOB(SGMII) test Target IP

    # PCIe Test Default Parameter
    DIAG_PCIE_TEST_ROUND_TIME=60                    # PCIe bus test one round time (unit : sec)

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # ***** 4C Internal Traffic Test ***** #

    # 1:EDVT        --- check packet no loss under full speed
    # 2:PT-PreTest  --- check packet no loss
    # 3:PT-BurnIn   --- check packet no loss under full speed

    DIAG_TRAFFIC_TEST_MODE="EDVT"

    DIAG_LINK_WAIT_TIME=1               # time to wait all ports link   (unit : sec)
    DIAG_TRAFFIC_TEST_PKT_TIME=1        # time to transmit packets      (unit : min) < can only set individually under PT mode >
    DIAG_TRAFFIC_TEST_PKT_LOSS_TOL=0    # packet loss number tolerance  (unit : number)
    DIAG_LOG_PARSE_TIME=15              # time to parse log (from MAC)  (unit : sec) < can only set by programmer > ## 20190130 : min to sec
    DIAG_TRAFFIC_TEST_SFP_SPEED=25      # 10 / 25                       (unit : Giga bytes)
    DIAG_TRAFFIC_TEST_QSFP_SPEED=100    # 10 /25 / 40 / 50 / 100        (unit : Giga bytes)
    DIAG_TRAFFIC_TEST_QSFPDD_SPEED="400g-pam4"  # 400g-pam4 (unit : Giga bytes)
    DIAG_TRAFFIC_TEST_AUTO_NEG="off"    # on / off
    DIAG_TRAFFIC_TEST_VLAN="on"         # on / off
    DIAG_TRAFFIC_TEST_INTERFACE="fiber" # DAC / fiber / mix / mix-1 / mix-2 / lbm (loopback module)
    DIAG_TRAFFIC_TEST_FEC="on"          # on / off
    DIAG_TRAFFIC_TEST_TX_PARA="off"     # off / static / dynamic
    DIAG_TRAFFIC_TEST_RCLOAD="./SDK/rc-packet-transmit.soc" # none / file name

    op_need_check_modules_plugged_status=$FALSE    # 20200914 add to make OP check modules' plugging ready or not.

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # ***** Stress Test ***** #

    # If current setting is positive/negative,
    # need to update the setting to negative/positive in configuration, then run the setting next round.
    # If current setting is normal,
    # keep the normal setting next round.

    DIAG_STRESS_TEST_VOLTAGE_SET="positive"  # positive(ex:+5%), negative(ex:-5%), normal
    DIAG_STRESS_TEST_WATT_SET="3.5"          # 1.0 / 1.5 / 2.0 / 2.5 / ... / 4.5 / 5.0 (unit : watt)

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # ***** Show Information ***** #

    DIAG_SHOW_CONFIG_PARA=1
    DIAG_SHOW_RESULT_SHORT=2

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # System LED Case Selection
    DIAG_SYS_LED_CASE_GREEN_ON=1        # Case 1 : All Burn-In Round PASS     ---> Green On
    DIAG_SYS_LED_CASE_AMBER_ON=2        # Case 2 : Burn-In Testing            ---> Amber On
    DIAG_SYS_LED_CASE_GREEN_BLINK=3     # Case 3 : Current Burn-In Round PASS ---> Green Blinking
    DIAG_SYS_LED_CASE_AMBER_BLINK=4     # Case 4 : Current Burn-In Round FAIL ---> Amber Blinking

    # System LED Control
    # 000x_xxxx  :  Green On
    # 001x_xxxx  :  Amber On
    # 010x_xxxx  :  Green & Amber Off
    # 011x_xxxx  :  Green Blinking
    # 100x_xxxx  :  Amber Blinking

    # System LED Mask
    DIAG_SYS_LED_AMBER_ON_MASK=0x20
    DIAG_SYS_LED_GREEN_BLINK_MASK=0x60
    DIAG_SYS_LED_AMBER_BLINK_MASK=0x80

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # Delay Time for Diagnostic Test
    DIAG_FILE_READ_DELAY_TIME=50000     # (unit : msec)
    DIAG_FILE_WRITE_DELAY_TIME=100000   # (unit : msec)
    DIAG_FILE_REMOVE_DELAY_TIME=100000  # (unit : msec)
    DIAG_CONF_UPDATE_DELAY_TIME=1       # (unit : sec)

    DIAG_FILE_EXIST_CHECK_WAIT_TIME=1   # (unit : sec)
    DIAG_FILE_EXIST_CHECK_CNT=10

    DIAG_PT_BURN_IN_ROUND_DELAY=20      # delay time between 2 burn-in round (unit : sec)
                                        # if have >=2 burn-in test to run, will delay between 2 burn-in round
}

# ======================================================================================================================================= #

function Write_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3
    i2c_data=$4

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cset -y $i2c_bus $i2c_device $i2c_register $i2c_data
    else
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_SET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE $i2c_data ; } 2>&1 )
    fi
    usleep $I2C_ACTION_DELAY
}

function Read_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register
        usleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE ; } 2>&1 )
        usleep $I2C_ACTION_DELAY
        ## 20200921 Due to BMC v3 will return fail msg, so need to add case to handle
        if [[ "$value_get_through_ipmi" == *"Unspecified error"* ]]; then
            ipmi_value_toHex=0x00
        else
            ipmi_value_toHex=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 2)))" ; } 2>&1 )    # orig value format is " XX" , so just get XX then transform as 0xXX format.
        fi
        echo $ipmi_value_toHex    # this line is to make return with value 0xXX
        return
    fi
}

function Mutex_Check_And_Create()
{
    ## check whether mutex key create by others process, if exist, wait until this procedure can create then keep go test.
    while [ -f $I2C_MUTEX_NODE ]
    do
        # echo " !!! Wait for I2C bus free !!!" |& tee -a $testLog
        sleep 1
        if [ ! -f $I2C_MUTEX_NODE ]; then
            break
        fi
    done
    ## create mutex key
    touch $I2C_MUTEX_NODE
    sync
    usleep 100000
}

function Mutex_Clean()
{
    rm $I2C_MUTEX_NODE
    sync
    usleep 100000
}

function Diag_Show_Info()
{
    show_info_sel=$1

    if (( $show_info_sel == $DIAG_SHOW_CONFIG_PARA )); then
        if [ -f "$DIAG_CONF_FILE_NAME" ]; then
            cat < "$DIAG_CONF_FILE_NAME"
            usleep $DIAG_FILE_READ_DELAY_TIME
        else
            printf "[MFG Error Msg] \"diag_test.conf\" NOT Exist\n"
        fi
    elif (( $show_info_sel == $DIAG_SHOW_RESULT_SHORT )); then
        if [ -f "$DIAG_PT_TEST_RESULT_LOG_NAME" ]; then
            cat < "$DIAG_PT_TEST_RESULT_LOG_NAME"
            usleep $DIAG_FILE_READ_DELAY_TIME
        else
            printf "[MFG Error Msg] \"diag_burn_in_result.log\" NOT Exist\n"
        fi
    fi
}

function Diag_Parameter_Default_Init()
{
    test_mode=$1

    if [[ "$test_mode" == "QTR" ]]; then
        DIAG_EDVT_SEL_TEST="External Traffic Test"
    elif [[ "$test_mode" == "PT" ]]; then
        DIAG_EDVT_SEL_TEST="Burn-In"
    fi
    user_edvt_sel_test=${DIAG_EDVT_SEL_TEST}    ## EDVT

    user_edvt_test_set=${DIAG_EDVT_TEST_SET}    ## EDVT
    user_edvt_test_time=${DIAG_EDVT_TEST_TIME}  ## EDVT

    user_burn_in_set=${DIAG_BURN_IN_SET}        ## PT
    user_thermal_test_set=${DIAG_THERMAL_TEST_SET}          ## THERMAL
    user_emc_test_set=${DIAG_EMC_TEST_SET}      ## EMC
    user_qtr_test_set=${DIAG_QTR_TEST_SET}      ## QTR
    user_safety_test_set=${DIAG_SAFETY_TEST_SET}            ## SAFETY
    user_fw_test_set=${DIAG_FW_UPGRADE_TEST_SET}            ## FW REGRESSION

    if [[ "$test_mode" == "EDVT" ]]; then
        user_pwr_cyc_num=${DIAG_EDVT_POWER_CYCLE_NUM}
    elif [[ "$test_mode" == "PT" ]]; then
        user_pwr_cyc_num=${DIAG_PT_POWER_CYCLE_NUM}
    fi
    user_burn_in_cyc_num=${DIAG_BURN_IN_CYCLE_NUM}  ## PT

    user_fan_pwm_bkp=${DIAG_FAN_PWM_BREAK_POINT}            ## PT
    user_fan_hspd_rpm_tlr=${DIAG_FAN_HIGH_SPEED_RPM_TLR}    ## PT
    user_fan_lspd_rpm_tlr=${DIAG_FAN_LOW_SPEED_RPM_TLR}     ## PT

    if [[ "$test_mode" == "EDVT" ]]; then
        DIAG_STORAGE_TEST_MODE="parallel"
        DIAG_TRAFFIC_TEST_MODE="EDVT"
        DIAG_TRAFFIC_TEST_INTERFACE="fiber"
    elif [[ "$test_mode" == "PT" ]]; then
        DIAG_STORAGE_TEST_MODE="sequential"
        DIAG_STORAGE_TEST_DEVICE="DRAM-eMMC-USB-SSD"
        DIAG_STORAGE_TEST_CNS_OUT="yes"
        DIAG_TRAFFIC_TEST_MODE="PT-BurnIn"
        DIAG_TRAFFIC_TEST_INTERFACE="lbm"
    elif [[ "$test_mode" == "THERMAL" ]]; then
        DIAG_STORAGE_TEST_MODE="parallel"
        DIAG_STORAGE_TEST_DEVICE="DRAM-eMMC-USB-SSD"
        DIAG_TRAFFIC_TEST_PKT_TIME="1440"           ## 24-hr
        DIAG_TRAFFIC_TEST_MODE="FLOODING"
        DIAG_TRAFFIC_TEST_INTERFACE="DAC"
        DIAG_TRAFFIC_TEST_VLAN="off"
    elif [[ "$test_mode" == "EMC" ]]; then
        DIAG_STORAGE_TEST_MODE="parallel"
        DIAG_STORAGE_TEST_DEVICE="DRAM-eMMC-USB"
        DIAG_STORAGE_TEST_CNS_OUT="yes"
        DIAG_TRAFFIC_TEST_PKT_TIME="120"            ## 2-hr
        DIAG_TRAFFIC_TEST_MODE="PT-BurnIn"
    elif [[ "$test_mode" == "SAFETY" ]]; then
        DIAG_STORAGE_TEST_MODE="parallel"
        DIAG_STORAGE_TEST_DEVICE="DRAM-eMMC-USB-SSD"
        DIAG_TRAFFIC_TEST_PKT_TIME="480"            ## 8-hr
        DIAG_TRAFFIC_TEST_MODE="PT-BurnIn"
    elif [[ "$test_mode" == "QTR" ]]; then
        DIAG_TRAFFIC_TEST_MODE="EDVT"
    elif [[ "$test_mode" == "FW_REGRESSION" ]]; then
        if [ -f $DIAG_FW_REGRESSION_ROUNDCHECK_FILE ];then
            rm $DIAG_FW_REGRESSION_ROUNDCHECK_FILE
        fi
        user_fw_test_round=5                        ## minimum cycle needed
        DIAG_TRAFFIC_TEST_MODE="PT-BurnIn"
        DIAG_TRAFFIC_TEST_INTERFACE="lbm"
    fi

    user_stg_mode=${DIAG_STORAGE_TEST_MODE}         ## EDVT, PT
    user_stg_size=${DIAG_STORAGE_TEST_SIZE}         ## EDVT, PT
    user_stg_dev=${DIAG_STORAGE_TEST_DEVICE}        ## EDVT, PT
    user_stg_cns_out=${DIAG_STORAGE_TEST_CNS_OUT}   ## PT

    user_oob_dut_ip=${DIAG_OOB_TEST_DUT_IP}         ## EDVT, PT, EMC
    user_oob_target_ip=${DIAG_OOB_TEST_TARGET_IP}   ## EDVT, PT, EMC

    user_pcie_test_rnd_time=${DIAG_PCIE_TEST_ROUND_TIME}    ## EDVT

    user_tfc_mode=${DIAG_TRAFFIC_TEST_MODE}
    user_tfc_link_wait_time=${DIAG_LINK_WAIT_TIME}              ## EDVT, PT, THERMAL, EMC
    user_tfc_pkt_time=${DIAG_TRAFFIC_TEST_PKT_TIME}             ## EDVT, PT, THERMAL, EMC
    user_tfc_pkt_loss_tol=${DIAG_TRAFFIC_TEST_PKT_LOSS_TOL}     ## EDVT, PT, THERMAL, EMC
    user_tfc_sfp_sp=${DIAG_TRAFFIC_TEST_SFP_SPEED}              ## EDVT, PT, THERMAL, EMC
    user_tfc_qsfp_sp=${DIAG_TRAFFIC_TEST_QSFP_SPEED}            ## EDVT, PT, THERMAL, EMC
    user_tfc_qsfpdd_sp=${DIAG_TRAFFIC_TEST_QSFPDD_SPEED}        ## EDVT, PT, THERMAL, EMC
    user_tfc_an=${DIAG_TRAFFIC_TEST_AUTO_NEG}                   ## EDVT, PT, THERMAL, EMC
    user_tfc_vl=${DIAG_TRAFFIC_TEST_VLAN}                       ## EDVT, PT, THERMAL, EMC
    user_tfc_if=${DIAG_TRAFFIC_TEST_INTERFACE}                  ## EDVT, PT, THERMAL, EMC
    user_tfc_fec=${DIAG_TRAFFIC_TEST_FEC}                       ## EDVT, PT, THERMAL, EMC

    user_vol_set=${DIAG_STRESS_TEST_VOLTAGE_SET}                ## EDVT, PT
    user_module_watt_set=${DIAG_STRESS_TEST_WATT_SET}           ## THERMAL, SAFETY
}

function Diag_Config_File_Update()
{
    ## Remove old configuration file.
    if [ -f "$DIAG_CONF_FILE_NAME" ]; then
        rm "$DIAG_CONF_FILE_NAME"
        usleep $DIAG_FILE_REMOVE_DELAY_TIME
        sync
    fi

    ## Create new configuration file.
    touch "$DIAG_CONF_FILE_NAME"
    usleep $DIAG_FILE_WRITE_DELAY_TIME
    sync

echo "Diagnostic Test Configuration File" >> "$DIAG_CONF_FILE_NAME"

    if [[ "$user_test_mode" == "EDVT" ]]; then
echo "
Project Name                :   $user_proj_name
Current Test Mode           :   $user_test_mode
Current Test Item           :   $user_edvt_sel_test

Test Setting
EDVT Test Set               :   $user_edvt_test_set
Power Cycle Number          :   $user_pwr_cyc_num
Current Power Cycle Round   :   $DIAG_CURRENT_POWER_CYCLE_ROUND
Test Time (min)             :   $user_edvt_test_time

Storage Test Parameter(s)
Test Mode                   :   $user_stg_mode
File Size (Mega bytes)      :   $user_stg_size
Test Device                 :   $user_stg_dev

OOB(SGMII) Test Parameter(s)
DUT IP                      :   $user_oob_dut_ip
Target IP                   :   $user_oob_target_ip

PCIe Bus Test Parameter
Test 1 round time (sec)     :   $user_pcie_test_rnd_time

Internal Traffic Test Parameter(s)
Test Mode                            :   $user_tfc_mode
Link-Waiting Time     (sec)          :   $user_tfc_link_wait_time
Packet-Loss Tolerance (number)       :   $user_tfc_pkt_loss_tol
SFP Speed             (Giga Bytes)   :   $user_tfc_sfp_sp" >> "$DIAG_CONF_FILE_NAME"
    if [[ "$PROJECT_NAME" == "ASTON" ]]; then
echo "QSFP-DD Speed            (Giga Bytes)   :   $user_tfc_qsfpdd_sp" >> "$DIAG_CONF_FILE_NAME"
    else
echo "QSFP Speed               (Giga Bytes)   :   $user_tfc_qsfp_sp" >> "$DIAG_CONF_FILE_NAME"
    fi
echo "Auto-Negotiation                        :   $user_tfc_an
VLAN                                    :   $user_tfc_vl
Interface                               :   $user_tfc_if
FEC                                     :   $user_tfc_fec
" >> "$DIAG_CONF_FILE_NAME"

echo "Stress Test Parameter
Voltage Setting (percent)   :   $user_vol_set
" >> "$DIAG_CONF_FILE_NAME"
    fi

## ========================================================================================== ##

    if [[ "$user_test_mode" == "PT" ]]; then
echo "
Project Name                :   $user_proj_name
Current Test Mode           :   $user_test_mode
Current Test Item           :   $user_edvt_sel_test

Test Setting
Traffic Test Set            :   $user_burn_in_set
Power Cycle Number          :   $user_pwr_cyc_num
Traffic Cycle Number        :   $user_burn_in_cyc_num
Current Power Cycle Round   :   $DIAG_CURRENT_POWER_CYCLE_ROUND

Fan Test Parameter(s)
Fan PWM Breakpoint Setting (percent)   :   $user_fan_pwm_bkp
High Speed RPM Tolerance   (percent)   :   $user_fan_hspd_rpm_tlr
Low Speed RPM Tolerance    (rpm)       :   $user_fan_lspd_rpm_tlr

Storage Test Parameter(s)
Test Mode                   :   $user_stg_mode
File Size (Mega bytes)      :   $user_stg_size
Test Device                 :   $user_stg_dev
Test Log Console Out        :   $user_stg_cns_out

Internal Traffic Test Parameter(s)
Test Mode                            :   $user_tfc_mode
Link-Waiting Time     (sec)          :   $user_tfc_link_wait_time
Packet-Transmitting Time (min)       :   $user_tfc_pkt_time
Packet-Loss Tolerance (number)       :   $user_tfc_pkt_loss_tol
SFP Speed             (Giga Bytes)   :   $user_tfc_sfp_sp" >> "$DIAG_CONF_FILE_NAME"
    if [[ "$PROJECT_NAME" == "ASTON" ]]; then
echo "QSFP-DD Speed            (Giga Bytes)   :   $user_tfc_qsfpdd_sp" >> "$DIAG_CONF_FILE_NAME"
    else
echo "QSFP Speed            (Giga Bytes)   :   $user_tfc_qsfp_sp" >> "$DIAG_CONF_FILE_NAME"
    fi
echo "Auto-Negotiation                        :   $user_tfc_an
VLAN                                    :   $user_tfc_vl
Interface                               :   $user_tfc_if
FEC                                     :   $user_tfc_fec

Stress Test Parameter
Voltage Setting (percent)   :   $user_vol_set
" >> "$DIAG_CONF_FILE_NAME"
    fi

## ========================================================================================== ##

    if [[ "$user_test_mode" == "THERMAL" ]]; then
echo "
Project Name                :   $user_proj_name
Current Test Mode           :   $user_test_mode

Test Setting
Thermal Test Set            :   $user_thermal_test_set
Test Time (min)             :   $user_tfc_pkt_time

Storage Test Parameter(s)
Test Mode                   :   $user_stg_mode
File Size (Mega bytes)      :   $user_stg_size
Test Device                 :   $user_stg_dev

Internal Traffic Test Parameter(s)
Test Mode                            :   $user_tfc_mode
Link-Waiting Time     (sec)          :   $user_tfc_link_wait_time
Packet-Loss Tolerance (number)       :   $user_tfc_pkt_loss_tol
SFP Speed             (Giga Bytes)   :   $user_tfc_sfp_sp" >> "$DIAG_CONF_FILE_NAME"
    if [[ "$PROJECT_NAME" == "ASTON" ]]; then
echo "QSFP-DD Speed            (Giga Bytes)   :   $user_tfc_qsfpdd_sp" >> "$DIAG_CONF_FILE_NAME"
    else
echo "QSFP Speed               (Giga Bytes)   :   $user_tfc_qsfp_sp" >> "$DIAG_CONF_FILE_NAME"
    fi
echo "Auto-Negotiation                        :   $user_tfc_an
VLAN                                    :   $user_tfc_vl
Interface                               :   $user_tfc_if
" >> "$DIAG_CONF_FILE_NAME"

echo "Stress Test Parameter
Module Loading (Watt)  :   $user_module_watt_set
" >> "$DIAG_CONF_FILE_NAME"
    fi

## ========================================================================================== ##

    if [[ "$user_test_mode" == "EMC" ]]; then
echo "
Project Name                :   $user_proj_name
Current Test Mode           :   $user_test_mode

Test Setting
EMC Test Set                :   $user_emc_test_set
Test Time (min)             :   $user_tfc_pkt_time

Storage Test Parameter(s)
Test Mode                   :   $user_stg_mode
File Size (Mega bytes)      :   $user_stg_size
Test Device                 :   $user_stg_dev

OOB(SGMII) Test Parameter(s)
DUT IP                      :   $user_oob_dut_ip
Target IP                   :   $user_oob_target_ip

Internal Traffic Test Parameter(s)
Test Mode                            :   $user_tfc_mode
Link-Waiting Time     (sec)          :   $user_tfc_link_wait_time
Packet-Loss Tolerance (number)       :   $user_tfc_pkt_loss_tol
SFP Speed             (Giga Bytes)   :   $user_tfc_sfp_sp" >> "$DIAG_CONF_FILE_NAME"
    if [[ "$PROJECT_NAME" == "ASTON" ]]; then
echo "QSFP-DD Speed            (Giga Bytes)   :   $user_tfc_qsfpdd_sp" >> "$DIAG_CONF_FILE_NAME"
    else
echo "QSFP Speed               (Giga Bytes)   :   $user_tfc_qsfp_sp" >> "$DIAG_CONF_FILE_NAME"
    fi
echo "Auto-Negotiation                        :   $user_tfc_an
VLAN                                    :   $user_tfc_vl
Interface                               :   $user_tfc_if
" >> "$DIAG_CONF_FILE_NAME"

    fi

## ========================================================================================== ##

    if [[ "$user_test_mode" == "SAFETY" ]]; then
echo "
Project Name                :   $user_proj_name
Current Test Mode           :   $user_test_mode

Test Setting
Safety Test Set             :   $user_safety_test_set
Test Time (min)             :   $user_tfc_pkt_time

Storage Test Parameter(s)
Test Mode                   :   $user_stg_mode
File Size (Mega bytes)      :   $user_stg_size
Test Device                 :   $user_stg_dev

Internal Traffic Test Parameter(s)
Test Mode                            :   $user_tfc_mode
Link-Waiting Time     (sec)          :   $user_tfc_link_wait_time
Packet-Loss Tolerance (number)       :   $user_tfc_pkt_loss_tol
SFP Speed             (Giga Bytes)   :   $user_tfc_sfp_sp" >> "$DIAG_CONF_FILE_NAME"
    if [[ "$PROJECT_NAME" == "ASTON" ]]; then
echo "QSFP-DD Speed            (Giga Bytes)   :   $user_tfc_qsfpdd_sp" >> "$DIAG_CONF_FILE_NAME"
    else
echo "QSFP Speed               (Giga Bytes)   :   $user_tfc_qsfp_sp" >> "$DIAG_CONF_FILE_NAME"
    fi
echo "Auto-Negotiation                        :   $user_tfc_an
VLAN                                    :   $user_tfc_vl
Interface                               :   $user_tfc_if
" >> "$DIAG_CONF_FILE_NAME"

echo "Stress Test Parameter
Module Loading (Watt)  :   $user_module_watt_set
" >> "$DIAG_CONF_FILE_NAME"
    fi

## ========================================================================================== ##

    if [[ "$user_test_mode" == "QTR" ]]; then
echo "
Project Name                :   $user_proj_name
Current Test Mode           :   $user_test_mode

Test Setting
QTR Test Set                :   $user_qtr_test_set

External Traffic Test Parameter(s)
Test Mode                            :   $user_tfc_mode
Link-Waiting Time     (sec)          :   $user_tfc_link_wait_time
Packet-Loss Tolerance (number)       :   $user_tfc_pkt_loss_tol
SFP Speed             (Giga Bytes)   :   $user_tfc_sfp_sp" >> "$DIAG_CONF_FILE_NAME"
    if [[ "$PROJECT_NAME" == "ASTON" ]]; then
echo "QSFP-DD Speed            (Giga Bytes)   :   $user_tfc_qsfpdd_sp" >> "$DIAG_CONF_FILE_NAME"
    else
echo "QSFP Speed               (Giga Bytes)   :   $user_tfc_qsfp_sp" >> "$DIAG_CONF_FILE_NAME"
    fi
echo "Auto-Negotiation                        :   $user_tfc_an
VLAN                                    :   $user_tfc_vl
Interface                               :   $user_tfc_if
FEC                                     :   $user_tfc_fec
" >> "$DIAG_CONF_FILE_NAME"

    fi

## ========================================================================================== ##

    if [[ "$user_test_mode" == "FW_REGRESSION" ]]; then
echo "
Project Name                :   $user_proj_name
Current Test Mode           :   $user_test_mode

Test Setting
FW Upgrade Test Set         :   $user_fw_test_set
Cycel Test Round            :   $user_fw_test_round
" >> "$DIAG_CONF_FILE_NAME"

    fi
## ========================================================================================== ##

    sleep $DIAG_CONF_UPDATE_DELAY_TIME
    sync

    ##for Rangeley init-ram.fs boot up.
    if [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
        cp $DIAG_CONF_FILE_NAME /home/root/eMMC/
        sync
    fi
}

function Diag_Config_File_Parsing()
{
    line_cnt=0

    while read string
    do
        line_cnt=$(( $line_cnt + 1 ))

        str_len=$( expr length "$string" )

        for (( i = 1; i <= $str_len; i += 1 ))
        do
            sub_str=$( expr substr "$string" $i 1 )

            if [[ "$sub_str" == ":" ]]; then
                para_str_start=$(( $i + 4 ))
                para_str_len=$(( $str_len - $para_str_start + 1 ))
                para_str=$( expr substr "$string" $para_str_start $para_str_len )

                if (( $DBG_PRINT_PARSE_CONF == $TRUE )); then
                    printf "[Diag Parse] [%d] %s\n" $line_cnt "$para_str"
                fi

                if (( $line_cnt == 3 )); then
                    user_proj_name="$para_str"
                elif (( $line_cnt == 4 )); then
                    user_test_mode="$para_str"
                fi

                if [[ "$user_test_mode" == "EDVT" ]]; then
                    case $line_cnt in
                        5) user_edvt_sel_test="$para_str"       ;;
                        # --------------------------------------------------------------------------- #
                        8)  user_edvt_test_set="$para_str"           ;;
                        9)  user_pwr_cyc_num=$para_str               ;;
                        10) DIAG_CURRENT_POWER_CYCLE_ROUND=$para_str ;;
                        11) user_edvt_test_time="$para_str"          ;;
                        # --------------------------------------------------------------------------- #
                        14) user_stg_mode="$para_str"           ;;
                        15) user_stg_size=$para_str             ;;
                        16) user_stg_dev="$para_str"            ;;
                        # --------------------------------------------------------------------------- #
                        19) user_oob_dut_ip="$para_str"         ;;
                        20) user_oob_target_ip="$para_str"      ;;
                        # --------------------------------------------------------------------------- #
                        23) user_pcie_test_rnd_time=$para_str   ;;
                        # --------------------------------------------------------------------------- #
                        26) user_tfc_mode="$para_str"
                            case $user_tfc_mode in
                                "EDVT")         user_tfc_mode_sel=1 ;;
                                "PT-PreTest")   user_tfc_mode_sel=2 ;;
                                "PT-BurnIn")    user_tfc_mode_sel=3 ;;
                                "FLOODING")     user_tfc_mode_sel=4 ;;
                                *)  ;;
                            esac
                            ;;
                        27) user_tfc_link_wait_time=$para_str    ;;
                        28) user_tfc_pkt_loss_tol=$para_str      ;;
                        # --------------------------------------------------------------------------- #
                        29) user_tfc_sfp_sp=$para_str            ;;
                        30)
                            if [[ "$PROJECT_NAME" == "ASTON" ]]; then
                                user_tfc_qsfpdd_sp=$para_str
                            else
                                user_tfc_qsfp_sp=$para_str
                            fi
                            ;;
                        31) user_tfc_an="$para_str"              ;;
                        32) user_tfc_vl="$para_str"              ;;
                        33) user_tfc_if="$para_str"              ;;
                        34) user_tfc_fec="$para_str"                 ;;
                        # --------------------------------------------------------------------------- #
                        37) user_vol_set="$para_str"             ;;
                        *)  ;;
                    esac
                elif [[ "$user_test_mode" == "PT" ]]; then
                    case $line_cnt in
                        5) user_edvt_sel_test="$para_str"            ;;
                        # --------------------------------------------------------------------------- #
                        8)  user_burn_in_set="$para_str"             ;;
                        9)  user_pwr_cyc_num=$para_str               ;;
                        10) user_burn_in_cyc_num=$para_str           ;;
                        11) DIAG_CURRENT_POWER_CYCLE_ROUND=$para_str ;;
                        # --------------------------------------------------------------------------- #
                        14) user_fan_pwm_bkp=$para_str               ;;
                        15) user_fan_hspd_rpm_tlr=$para_str          ;;
                        16) user_fan_lspd_rpm_tlr=$para_str          ;;
                        # --------------------------------------------------------------------------- #
                        19) user_stg_mode="$para_str"                ;;
                        20) user_stg_size="$para_str"                ;;
                        21) user_stg_dev="$para_str"                 ;;
                        22) user_stg_cns_out="$para_str"             ;;
                        # --------------------------------------------------------------------------- #
                        25) user_tfc_mode="$para_str"
                            case $user_tfc_mode in
                                "EDVT")         user_tfc_mode_sel=1 ;;
                                "PT-PreTest")   user_tfc_mode_sel=2 ;;
                                "PT-BurnIn")    user_tfc_mode_sel=3 ;;
                                "FLOODING")     user_tfc_mode_sel=4 ;;
                                "PT-4C")        user_tfc_mode_sel=5 ;;
                                *)  ;;
                            esac
                            ;;
                        26) user_tfc_link_wait_time=$para_str        ;;
                        27) user_tfc_pkt_time=$para_str              ;;
                        28) user_tfc_pkt_loss_tol=$para_str          ;;
                        # --------------------------------------------------------------------------- #
                        29) user_tfc_sfp_sp=$para_str                ;;
                        30)
                            if [[ "$PROJECT_NAME" == "ASTON" ]]; then
                                user_tfc_qsfpdd_sp=$para_str
                            else
                                user_tfc_qsfp_sp=$para_str
                            fi
                            ;;
                        31) user_tfc_an="$para_str"                  ;;
                        32) user_tfc_vl="$para_str"                  ;;
                        33) user_tfc_if="$para_str"                  ;;
                        34) user_tfc_fec="$para_str"                 ;;
                        # --------------------------------------------------------------------------- #
                        37) user_vol_set="$para_str"                 ;;
                        *)  ;;
                    esac
                elif [[ "$user_test_mode" == "THERMAL" ]]; then
                    case $line_cnt in
                        7)  user_thermal_test_set="$para_str"        ;;
                        8)  user_tfc_pkt_time="$para_str"            ;;
                        # --------------------------------------------------------------------------- #
                        11) user_stg_mode="$para_str"                ;;
                        12) user_stg_size="$para_str"                ;;
                        13) user_stg_dev="$para_str"                 ;;
                        # --------------------------------------------------------------------------- #
                        16) user_tfc_mode="$para_str"
                            case $user_tfc_mode in
                                "EDVT")         user_tfc_mode_sel=1 ;;
                                "PT-PreTest")   user_tfc_mode_sel=2 ;;
                                "PT-BurnIn")    user_tfc_mode_sel=3 ;;
                                "FLOODING")     user_tfc_mode_sel=4 ;;
                                *)  ;;
                            esac
                            ;;
                        17) user_tfc_link_wait_time="$para_str"        ;;
                        18) user_tfc_pkt_loss_tol="$para_str"          ;;
                        19) user_tfc_sfp_sp="$para_str"                ;;
                        20)
                            if [[ "$PROJECT_NAME" == "ASTON" ]]; then
                                user_tfc_qsfpdd_sp="$para_str"
                            else
                                user_tfc_qsfp_sp="$para_str"
                            fi
                            ;;
                        21) user_tfc_an="$para_str"                  ;;
                        22) user_tfc_vl="$para_str"                  ;;
                        23) user_tfc_if="$para_str"                  ;;
                        # --------------------------------------------------------------------------- #
                        26) user_module_watt_set="$para_str"         ;;
                        *)  ;;
                    esac
                elif [[ "$user_test_mode" == "EMC" ]]; then
                    case $line_cnt in
                        7)  user_emc_test_set="$para_str"        ;;
                        8)  user_tfc_pkt_time="$para_str"            ;;
                        # --------------------------------------------------------------------------- #
                        11) user_stg_mode="$para_str"                ;;
                        12) user_stg_size="$para_str"                ;;
                        13) user_stg_dev="$para_str"                 ;;
                        # --------------------------------------------------------------------------- #
                        16) user_oob_dut_ip="$para_str"              ;;
                        17) user_oob_target_ip="$para_str"           ;;
                        # --------------------------------------------------------------------------- #
                        20) user_tfc_mode="$para_str"
                            case $user_tfc_mode in
                                "EDVT")         user_tfc_mode_sel=1 ;;
                                "PT-PreTest")   user_tfc_mode_sel=2 ;;
                                "PT-BurnIn")    user_tfc_mode_sel=3 ;;
                                "FLOODING")     user_tfc_mode_sel=4 ;;
                                *)  ;;
                            esac
                            ;;
                        21) user_tfc_link_wait_time="$para_str"        ;;
                        22) user_tfc_pkt_loss_tol="$para_str"          ;;
                        23) user_tfc_sfp_sp="$para_str"                ;;
                        24)
                            if [[ "$PROJECT_NAME" == "ASTON" ]]; then
                                user_tfc_qsfpdd_sp="$para_str"
                            else
                                user_tfc_qsfp_sp="$para_str"
                            fi
                            ;;
                        25) user_tfc_an="$para_str"                  ;;
                        26) user_tfc_vl="$para_str"                  ;;
                        27) user_tfc_if="$para_str"                  ;;
                        *)  ;;
                    esac
                elif [[ "$user_test_mode" == "SAFETY" ]]; then
                    case $line_cnt in
                        7)  user_safety_test_set="$para_str"        ;;
                        8)  user_tfc_pkt_time="$para_str"            ;;
                        # --------------------------------------------------------------------------- #
                        11) user_stg_mode="$para_str"                ;;
                        12) user_stg_size="$para_str"                ;;
                        13) user_stg_dev="$para_str"                 ;;
                        # --------------------------------------------------------------------------- #
                        16) user_tfc_mode="$para_str"
                            case $user_tfc_mode in
                                "EDVT")         user_tfc_mode_sel=1 ;;
                                "PT-PreTest")   user_tfc_mode_sel=2 ;;
                                "PT-BurnIn")    user_tfc_mode_sel=3 ;;
                                "FLOODING")     user_tfc_mode_sel=4 ;;
                                *)  ;;
                            esac
                            ;;
                        17) user_tfc_link_wait_time="$para_str"        ;;
                        18) user_tfc_pkt_loss_tol="$para_str"          ;;
                        19) user_tfc_sfp_sp="$para_str"                ;;
                        20)
                            if [[ "$PROJECT_NAME" == "ASTON" ]]; then
                                user_tfc_qsfpdd_sp="$para_str"
                            else
                                user_tfc_qsfp_sp="$para_str"
                            fi
                            ;;
                        21) user_tfc_an="$para_str"                  ;;
                        22) user_tfc_vl="$para_str"                  ;;
                        23) user_tfc_if="$para_str"                  ;;
                        # --------------------------------------------------------------------------- #
                        26) user_module_watt_set="$para_str"         ;;
                        *)  ;;
                    esac
                elif [[ "$user_test_mode" == "QTR" ]]; then
                    case $line_cnt in
                        7)  user_qtr_test_set="$para_str"            ;;
                        # --------------------------------------------------------------------------- #
                        10) user_tfc_mode="$para_str"
                            case $user_tfc_mode in
                                "EDVT")         user_tfc_mode_sel=1 ;;
                                "PT-PreTest")   user_tfc_mode_sel=2 ;;
                                "PT-BurnIn")    user_tfc_mode_sel=3 ;;
                                "FLOODING")     user_tfc_mode_sel=4 ;;
                                *)  ;;
                            esac
                            ;;
                        11) user_tfc_link_wait_time="$para_str"        ;;
                        12) user_tfc_pkt_loss_tol="$para_str"          ;;
                        13) user_tfc_sfp_sp="$para_str"                ;;
                        14)
                            if [[ "$PROJECT_NAME" == "ASTON" ]]; then
                                user_tfc_qsfpdd_sp="$para_str"
                            else
                                user_tfc_qsfp_sp="$para_str"
                            fi
                            ;;
                        15) user_tfc_an="$para_str"                  ;;
                        16) user_tfc_vl="$para_str"                  ;;
                        17) user_tfc_if="$para_str"                  ;;
                        18) user_tfc_fec="$para_str"                 ;;
                        *)  ;;
                    esac
                elif [[ "$user_test_mode" == "FW_REGRESSION" ]]; then
                    case $line_cnt in
                        7)  user_fw_test_set="$para_str"             ;;
                        8)  user_fw_test_round="$para_str"           ;;
                        *)  ;;
                    esac
                fi
            fi
        done
    done < "$DIAG_CONF_FILE_NAME"
}

function Diag_Parsing_Test_Result()
{
    curr_burn_in_round=$1
    test_item=$2
    file_name=$3

    read string < "$file_name"

    # Parsing test result.
    case $test_item in
        1)
            test_item_str=$( expr substr "$string" 1 8 )
            if [[ "$test_item_str" == "Fan Test" ]]; then
                # Fan Test Result : PASS
                test_item_result=$( expr substr "$string" 19 4 )
            fi

            if [[ "$test_item_result" == "FAIL" ]]; then
                DIAG_FAN_TEST_RESULT=$FAIL
            fi

            # Show test results.
            printf "\n"
            printf "===> %s Result : %s\n" "$test_item_str" "$test_item_result"
            ;;
        2)
            test_item_str=$( expr substr "$string" 1 12 )
            if [[ "$test_item_str" == "Storage Test" ]]; then
                # Storage Test Result : PASS
                test_item_result=$( expr substr "$string" 23 4 )
            fi

            if [[ "$test_item_result" == "FAIL" ]]; then
                DIAG_STORAGE_TEST_RESULT=$FAIL
            fi

            printf "\n"
            printf "===> %s Result : %s\n" "$test_item_str" "$test_item_result"
            ;;
        3)
            test_item_str=$( expr substr "$string" 1 12 )
            if [[ "$test_item_str" == "Traffic Test" ]]; then
                test_item_result=$( expr substr "$string" 23 4 )
            fi

            if [[ "$test_item_result" == "FAIL" ]]; then
                DIAG_TRAFFIC_TEST_RESULT=$FAIL
                #burn_in_result[$curr_burn_in_round]=$FAIL
            fi
            printf "\n"

            if (( $user_burn_in_cyc_num == 1 )); then
                printf "===> %s Result : %s\n" "$test_item_str" "$test_item_result"
            else
                printf "===> %s Round %d Result : %s\n" "$test_item_str" "$curr_burn_in_round" "$test_item_result"
            fi
            ;;
        *)  ;;
    esac
}

function Diag_System_LED_Status()
{
    sys_led_case=$1

    if (( $DBG_SYS_LED_STATUS == $TRUE )); then
        printf "[MFG Debug] [%s] Burn-In LED : %d\n" "$user_proj_name" $sys_led_case
    fi

    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    # Switch I2C Mux to CPLD
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_SYSTEM_LED

    # Get system LED status from CPLD LED control register.
    led_ctrl_reg_val=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG; } 2>&1 )

    # Clear [7:5] bits of LED control register (System-Status LED Control Bits).
    sys_led_status=$(( $led_ctrl_reg_val & 0x1F ))

    case $sys_led_case in
        $DIAG_SYS_LED_CASE_AMBER_ON)
            sys_led_status=$(( $sys_led_status | $DIAG_SYS_LED_AMBER_ON_MASK ))
            if (( $DBG_SYS_LED_STATUS == $TRUE )); then
                printf "[MFG Debug] System LED Amber On (0x%x)\n" $sys_led_status
            fi
            ;;
        $DIAG_SYS_LED_CASE_GREEN_BLINK)
            sys_led_status=$(( $sys_led_status | $DIAG_SYS_LED_GREEN_BLINK_MASK ))
            if (( $DBG_SYS_LED_STATUS == $TRUE )); then
                printf "[MFG Debug] System LED Green Blink (0x%x)\n" $sys_led_status
            fi
            ;;
        $DIAG_SYS_LED_CASE_AMBER_BLINK)
            sys_led_status=$(( $sys_led_status | $DIAG_SYS_LED_AMBER_BLINK_MASK ))
            if (( $DBG_SYS_LED_STATUS == $TRUE )); then
                printf "[MFG Debug] System LED Amber Blink (0x%x)\n" $sys_led_status
            fi
            ;;
        *)
            if (( $DBG_SYS_LED_STATUS == $TRUE )); then
                printf "[MFG Debug] System LED Green On\n"
            fi
            ;;
    esac

    # Set LED status to CPLD LED control register.
    Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $sys_led_status
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG 0x0

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi
}

function Diag_Run_EDVT_Test()
{
    echo "[Diag Msg] Start EDVT test -- Round $DIAG_CURRENT_POWER_CYCLE_ROUND "

    ## Remove old test result when run new power cycle round.
    if (( $DIAG_CURRENT_POWER_CYCLE_ROUND == 1 )); then
        Diag_Remove_Old_Log "$user_test_mode"
    fi

    ## 4C Test Voltage Setting
    if (( $EDVT_REQUEST_REMAIN_VOLTAGE_SETTING )); then   ## For remain voltage setting in every power cycle.
        bash ${MFG_SOURCE_DIR}/voltage_control.sh npu=$user_vol_set mb=$user_vol_set testRound=$DIAG_CURRENT_POWER_CYCLE_ROUND
    else
        bash ${MFG_SOURCE_DIR}/voltage_control.sh npu=$user_vol_set mb=$user_vol_set testRound=$DIAG_CURRENT_POWER_CYCLE_ROUND
        if [[ "$user_vol_set" == "positive" ]]; then
            sed -i "37,37d" "$DIAG_CONF_FILE_NAME"
            sed -i "37i Voltage Setting    (percent)      :   negative" "$DIAG_CONF_FILE_NAME"
        elif [[ "$user_vol_set" == "negative" ]]; then
            sed -i "37,37d" "$DIAG_CONF_FILE_NAME"
            sed -i "37i Voltage Setting    (percent)      :   positive" "$DIAG_CONF_FILE_NAME"
        fi
        sync
    fi

    cmp_test_time=$(( $user_edvt_test_time * 60 ))

    cmp_test_para_str="${DIAG_CURRENT_POWER_CYCLE_ROUND} "
    cmp_test_para_str+="${user_test_mode} "
    cmp_test_para_str+="${user_stg_mode} ${user_stg_size} ${user_stg_dev} ${DIAG_STORAGE_TEST_CNS_OUT} "
    cmp_test_para_str+="${cmp_test_time} "
    cmp_test_para_str+="${user_oob_dut_ip} ${user_oob_target_ip} "
    cmp_test_para_str+="${user_proj_name} "
    cmp_test_para_str+="${user_pcie_test_rnd_time} "
    cmp_test_para_str+="${user_edvt_sel_test}"
    #echo "[Diag Debug] cmp_test_para_str: ${cmp_test_para_str}"
    if [[ "$user_edvt_sel_test" == "4C Component Test" ]]; then
        bash ${MFG_SOURCE_DIR}/diag_component_test.sh ${cmp_test_para_str}

    elif [[ "$user_edvt_sel_test" == "4C Component + External Traffic Test" ]]; then
        bash ${MFG_SOURCE_DIR}/diag_component_test.sh ${cmp_test_para_str}

        ## ! Add each project's SDK entry point here !
        if [[ "$user_proj_name" == "Gemini" ]]; then
            bash ${MFG_SOURCE_DIR}/gemini_sdk_start.sh qsfp=$user_tfc_qsfp_sp sfp=$user_tfc_sfp_sp if=$user_tfc_if vlan=$user_tfc_vl fec=$user_tfc_fec
        elif [[ "$user_proj_name" == "Aston" ]]; then
            echo "[Diag Msg] Aston NOT support External Traffic Test Mode for EDVT !!!"
            exit 1
        elif [[ "$user_proj_name" == "Porsche" ]]; then
            ./sdk_ref
        fi

    elif [[ "$user_edvt_sel_test" == "4C Internal Traffic Test" ]]; then
        if [[ "$user_proj_name" == "Bugatti" ]]; then
            bash ${MFG_SOURCE_DIR}/diag_bcm_traffic_test.sh $user_tfc_mode_sel $DIAG_LINK_WAIT_TIME $user_tfc_pkt_time $DIAG_LOG_PARSE_TIME $user_tfc_sfp_sp $user_tfc_qsfp_sp "$user_tfc_an" "$user_tfc_vl" "$user_tfc_if"
        elif [[ "$user_proj_name" == "Porsche" ]]; then
            bash ${MFG_SOURCE_DIR}/diag_nps_traffic_test.sh $DIAG_CURRENT_POWER_CYCLE_ROUND $burn_in_round $user_tfc_mode_sel $user_tfc_pkt_time
        elif [[ "$user_proj_name" == "Aston" ]]; then
            tfc_test_para_str="pwr-cyc-rnd=${DIAG_CURRENT_POWER_CYCLE_ROUND} "
            tfc_test_para_str+="tfc-mode=${TRAFFIC_TEST_MODE_EDVT_INTERNAL} "
            tfc_test_para_str+="tfc-pkt-t=${cmp_test_time} "
            tfc_test_para_str+="tfc-qsfpdd-sp=${user_tfc_qsfpdd_sp} "
            tfc_test_para_str+="port-start=0 port-end=248"
            #echo "[Diag Debug] tfc_test_para_str: ${tfc_test_para_str}"
            bash ${MFG_SOURCE_DIR}/diag_nps_traffic_test.sh ${tfc_test_para_str}
        fi

    elif [[ "$user_edvt_sel_test" == "4C Component + Internal Traffic Test" ]]; then
        bash ${MFG_SOURCE_DIR}/diag_component_test.sh ${cmp_test_para_str}

        sleep 3 # !!! If no sleep here, traffic test will not run correctly. Reason need to check.

        if [[ "$user_proj_name" == "Bugatti" ]]; then
            bash ${MFG_SOURCE_DIR}/diag_bcm_traffic_test.sh $user_tfc_mode_sel $DIAG_LINK_WAIT_TIME $user_edvt_test_time $DIAG_LOG_PARSE_TIME $user_tfc_sfp_sp $user_tfc_qsfp_sp "$user_tfc_an" "$user_tfc_vl" "$user_tfc_if"
        elif [[ "$user_proj_name" == "Porsche" ]]; then
            bash ${MFG_SOURCE_DIR}/diag_nps_traffic_test.sh $DIAG_CURRENT_POWER_CYCLE_ROUND $burn_in_round $user_tfc_mode_sel $user_tfc_pkt_time
        elif [[ "$user_proj_name" == "Aston" ]]; then
            tfc_test_para_str="pwr-cyc-rnd=${DIAG_CURRENT_POWER_CYCLE_ROUND} "
            tfc_test_para_str+="tfc-mode=${TRAFFIC_TEST_MODE_EDVT_INTERNAL} "
            tfc_test_para_str+="tfc-pkt-t=${cmp_test_time} "
            tfc_test_para_str+="tfc-qsfpdd-sp=${user_tfc_qsfpdd_sp} "
            tfc_test_para_str+="port-start=0 port-end=248"
            #echo "[Diag Debug] tfc_test_para_str: ${tfc_test_para_str}"
            bash ${MFG_SOURCE_DIR}/diag_nps_traffic_test.sh ${tfc_test_para_str}
        fi

    elif [[ "$user_edvt_sel_test" == "External Traffic Test" ]]; then
        ## ! Add each project' s SDK entry point here !
        if [[ "$user_proj_name" == "Gemini" ]]; then
            bash ${MFG_SOURCE_DIR}/gemini_sdk_start.sh qsfp=100 sfp=25 if=fiber vlan=on fec=on
        elif [[ "$user_proj_name" == "Porsche" ]]; then
            bash ${MFG_SOURCE_DIR}/porsche2_sdk_start.sh qsfp=100 sfp=25 if=fiber vlan=on fec=on
        fi

    else
        echo "[Diag Error Msg] \"$user_edvt_sel_test\" EDVT test mode NOT support !!!"
        exit 1
    fi

    DIAG_CURRENT_POWER_CYCLE_ROUND=$(( $DIAG_CURRENT_POWER_CYCLE_ROUND + 1 ))

    if (( $DIAG_CURRENT_POWER_CYCLE_ROUND > $user_pwr_cyc_num )); then
        ## If next power cycle round > power cycle number,
        ## then turn-off burn-in flag and write to configuration file.
        sed -i "8,8d" "$DIAG_CONF_FILE_NAME"
        sed -i "8i EDVT Test Set               :   off" "$DIAG_CONF_FILE_NAME"
        printf "\n[Diag Msg] All Power Cycle are Finished\n"

        ## Set main board voltage to normal mode after all power cycle are finished.
        bash ${MFG_SOURCE_DIR}/voltage_control.sh npu=normal mb=normal

        Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
    else
        ## If next power cycle round <= power cycle number,
        ## then write next power cycle round to configuration file.
        sed -i "10,10d" "$DIAG_CONF_FILE_NAME"
        sed -i "10i Current Power Cycle Round   :   $DIAG_CURRENT_POWER_CYCLE_ROUND" "$DIAG_CONF_FILE_NAME"
        printf "\n[Diag Msg] Current Power Cycle are Finished\n"
    fi
    sync

    if [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
        cp $DIAG_CONF_FILE_NAME /home/root/eMMC/
        sync
    fi
}

function Diag_Run_PT_4C_Test()
{
    file_exist_retry=0

    echo "[Diag Msg] Start PT 4C test -- Cycle $DIAG_CURRENT_POWER_CYCLE_ROUND "

    ## Remove old test result when run new power cycle round.
    if (( $DIAG_CURRENT_POWER_CYCLE_ROUND == 1 )); then
        Diag_Remove_Old_Log "$user_test_mode"
    fi

    echo "Current Cycle : $DIAG_CURRENT_POWER_CYCLE_ROUND" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
    sync

    ## 4C Test Voltage Setting
    if (( $EDVT_REQUEST_REMAIN_VOLTAGE_SETTING )); then   ## For remain voltage setting in every power cycle.
        bash ${MFG_SOURCE_DIR}/voltage_control.sh npu=$user_vol_set mb=$user_vol_set testRound=$DIAG_CURRENT_POWER_CYCLE_ROUND
    else
        bash ${MFG_SOURCE_DIR}/voltage_control.sh npu=$user_vol_set mb=$user_vol_set testRound=$DIAG_CURRENT_POWER_CYCLE_ROUND
        if [[ "$user_vol_set" == "positive" ]]; then
            sed -i "37,37d" "$DIAG_CONF_FILE_NAME"
            sed -i "37i Voltage Setting    (percent)      :   negative" "$DIAG_CONF_FILE_NAME"
        elif [[ "$user_vol_set" == "negative" ]]; then
            sed -i "37,37d" "$DIAG_CONF_FILE_NAME"
            sed -i "37i Voltage Setting    (percent)      :   positive" "$DIAG_CONF_FILE_NAME"
        fi
        sync
    fi

    cmp_test_time=$(( $user_tfc_pkt_time * 60 ))

    cmp_test_para_str="${DIAG_CURRENT_POWER_CYCLE_ROUND} "
    cmp_test_para_str+="${user_test_mode} "
    cmp_test_para_str+="${user_stg_mode} ${user_stg_size} ${user_stg_dev} ${DIAG_STORAGE_TEST_CNS_OUT} "
    cmp_test_para_str+="${cmp_test_time} "
    cmp_test_para_str+="Empty Empty "        ## OOB IP        , although no use, but still need to be passed to diag-component script.
    cmp_test_para_str+="${user_proj_name} "
    cmp_test_para_str+="0 "                   ## PCIe test time, although no use, but still need to be passed to diag-component script.
    cmp_test_para_str+="${user_burn_in_cyc_num}"
    # echo "[Diag Debug] cmp_test_para_str: ${cmp_test_para_str}"

    bash ${MFG_SOURCE_DIR}/diag_component_test.sh ${cmp_test_para_str} &

    sleep 3 # !!! If no sleep here, traffic test will not run correctly. Reason need to check.

    ## ! Add each project's SDK with burn-in here !
    if [[ "$user_proj_name" == "Gemini" ]]; then
        bash ${MFG_SOURCE_DIR}/diag_marvell_traffic_test.sh $user_tfc_mode_sel $DIAG_CURRENT_POWER_CYCLE_ROUND $user_tfc_pkt_time $user_tfc_if $user_burn_in_cyc_num
    fi

    ## base on result to decide SYSLED behavior
    # storage (== burn-in item-2) result log @ $LOG_DIAG_COMPONENT_RESULT_TMP
    DIAG_STORAGE_TEST_RESULT=$PASS
    test_result_log_file_name=$LOG_DIAG_COMPONENT_RESULT_TMP
    if [ -f "$test_result_log_file_name" ]; then
        Diag_Parsing_Test_Result $DIAG_CURRENT_POWER_CYCLE_ROUND 2 "$test_result_log_file_name"

        read test_result_string < "$test_result_log_file_name"
        echo "    $test_result_string" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
        sync
    else
        printf "[Diag Error Msg] %s File NOT Exist\n" "$test_result_log_file_name"
    fi

    # I2C test result log @ $LOG_DIAG_I2C_RESULT_TMP
    DIAG_I2C_TEST_RESULT=$PASS
    test_result_log_file_name="$LOG_PATH_I2C/i2c_bus_test_cycle_$DIAG_CURRENT_POWER_CYCLE_ROUND.log"
    test_item_str="I2C     Test"        ## format only for aligh others string.
    for (( ck = 1 ; ck <= 3 ; ck++ ))
    do
        if [ -f "$test_result_log_file_name" ]; then
            check_result=$( { grep -n "FAIL" "$test_result_log_file_name" ; } 2>&1 )
            if [ ! -z "$check_result" ]; then
                DIAG_I2C_TEST_RESULT=$FAIL
                echo "    $test_item_str Result : FAIL" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
                printf "\n===> %s Result : FAIL\n" "$test_item_str"
            else
                echo "    $test_item_str Result : PASS" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
                printf "\n===> %s Result : PASS\n" "$test_item_str"
            fi
            sync

            break
        else
            printf "[Diag Msg] Wait %s File ... \n" "$test_result_log_file_name"
            file_exist_retry=$(( file_exist_retry + 1 ))
        fi
        sleep 5
    done
    if (( $file_exist_retry >= 5 )); then
        printf "[Diag Error Msg] %s File NOT Exist\n" "$test_result_log_file_name"
    fi

    # traffic (== burn-in item-3) result log @ $LOG_DIAG_TRAFFIC_RESULT_TMP
    DIAG_TRAFFIC_TEST_RESULT=$PASS
    test_result_log_file_name=$LOG_DIAG_TRAFFIC_RESULT_TMP
    if [ -f "$test_result_log_file_name" ]; then
        Diag_Parsing_Test_Result $DIAG_CURRENT_POWER_CYCLE_ROUND 3 "$test_result_log_file_name"

        read test_result_string < "$test_result_log_file_name"
        echo "    $test_result_string" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
        sync
    else
        printf "[Diag Error Msg] %s File NOT Exist\n" "$test_result_log_file_name"
    fi

    # total items result
    if (( $DIAG_I2C_TEST_RESULT == $FAIL )) || (( $DIAG_STORAGE_TEST_RESULT == $FAIL )) || (( $DIAG_TRAFFIC_TEST_RESULT == $FAIL )); then
        DIAG_TEST_RESULT=$FAIL
        echo "Cycle Test Result : FAIL" > "${LOG_PATH_HOME}/diag_burn_in_result_$DIAG_CURRENT_POWER_CYCLE_ROUND.log"
    else
        DIAG_TEST_RESULT=$PASS
        echo "Cycle Test Result : PASS" > "${LOG_PATH_HOME}/diag_burn_in_result_$DIAG_CURRENT_POWER_CYCLE_ROUND.log"
    fi

    ## current power cycle count +1
    DIAG_CURRENT_POWER_CYCLE_ROUND=$(( $DIAG_CURRENT_POWER_CYCLE_ROUND + 1 ))

    if (( $DIAG_CURRENT_POWER_CYCLE_ROUND > $user_pwr_cyc_num )); then
        printf "\n[Diag Msg] All Power Cycle are Finished\n"

        ## check all rounds' final result, to decide the LED behavior.
        total_result=$( { grep -n "FAIL" ${LOG_PATH_HOME}/diag_burn_in_result_*.log | wc -l ; } 2>&1 )
        if (( $total_result > 0 )); then
            DIAG_TEST_RESULT=$FAIL
        else
            DIAG_TEST_RESULT=$PASS
        fi

        if (( $DIAG_TEST_RESULT == $PASS )); then
            printf "           Power Cycle Result : PASS\n"
            echo "===> Power Cycle Result : PASS" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
            echo "" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"

            ## All burn-in round pass. (Turn System-Status LED Green On)
            Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON

            echo "pass" > $DIAG_BURNIN_RESULT_NOTE
            sync
        elif (( $DIAG_TEST_RESULT == $FAIL )); then
            printf "           Power Cycle Result : FAIL\n"
            echo "===> Power Cycle Result : FAIL" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
            echo "" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"

            ## Final burn-in result fail. (Turn System-Status LED Amber Blink)
            Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_BLINK

            echo "fail" > $DIAG_BURNIN_RESULT_NOTE
            sync
        fi

        ## Turn-off burn-in flag and write to configuration file.
        sed -i "8,8d" "$DIAG_CONF_FILE_NAME"
        sed -i "8i Traffic Test Set            :   off" "$DIAG_CONF_FILE_NAME"    # Burn-In Set
        sync
    else
        if (( $DIAG_TEST_RESULT == $PASS )); then
            printf "           Power Cycle Result : PASS\n"
            echo "===> Power Cycle Result : PASS" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
            echo "" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"

            ## Current burn-in round test pass. (Turn System-Status LED Green Blinking)
            Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_BLINK

        elif (( $DIAG_TEST_RESULT == $FAIL )); then
            printf "           Power Cycle Result : FAIL\n"
            echo "===> Power Cycle Result : FAIL" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
            echo "" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"

            ## Final burn-in result fail. (Turn System-Status LED Amber Blink)
            Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_BLINK
        fi

        ## If next power cycle round <= power cycle number,
        ## then write next power cycle round to configuration file.
        sed -i "11,11d" "$DIAG_CONF_FILE_NAME"
        sed -i "11i Current Power Cycle Round   :   $DIAG_CURRENT_POWER_CYCLE_ROUND" "$DIAG_CONF_FILE_NAME"

        ## for factory production request (due to no power cycler)
        if (( 1 )); then
        if [[ "$user_proj_name" == "Gemini" ]]; then
            sync
            sleep 10
            ## 20200918 Use BDX CPLD reg4,bit1 to trigger full reset
            Mutex_Check_And_Create
            if (( $FLAG_USE_IPMI == "$TRUE" )); then
                swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
            fi

            npu_cpld_ctrl_reg_val=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_MISC_CNTL_REG ; } 2>&1 )
            write_data=$(( $npu_cpld_ctrl_reg_val & 0xfd ))
            Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_MISC_CNTL_REG $write_data

            Mutex_Clean
            if (( $FLAG_USE_IPMI == "$TRUE" )); then
                swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
            fi
        fi
        fi
        ## Add End
    fi
    sync

    if [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
        cp $DIAG_CONF_FILE_NAME /home/root/eMMC/
        sync
    fi
}

function Diag_Run_PT_BurnIn_Test()
{
    ## Initial burn-in test variables.
    DIAG_TEST_RESULT=$PASS

    echo "[Diag Msg] Start PT Burn-In test"

    #for (( round = 1; round <= $user_burn_in_cyc_num; round += 1 ))
    #do
    #    burn_in_result[$round]=$PASS
    #done

    ## Remove old test result when run new power cycle round.
    if (( $DIAG_CURRENT_POWER_CYCLE_ROUND == 1 )); then
        Diag_Remove_Old_Log "$user_test_mode"
    fi

    # ====================================================================================================================================================== #

    printf "\n[Diag Msg] Power Cycle Round %d Start\n" $DIAG_CURRENT_POWER_CYCLE_ROUND
    echo "Current Power Cycle Round : $DIAG_CURRENT_POWER_CYCLE_ROUND" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
    sync

    ## Set loopback module loading to 3.5W
    printf "\n[Diag Msg] Setting loopback module loading to 3.5(W).\n"
    bash ${MFG_SOURCE_DIR}/module_voltage_control.sh 3.5
    sleep 1

    pt_test_step=1
    while (( $pt_test_step <= 3 ))
    do
        case $pt_test_step in
            1)  ## Fan Test
                printf "\n\n################################### Fan Test Start ###################################\n\n"

                bash ${MFG_SOURCE_DIR}/diag_fan_test.sh $DIAG_CURRENT_POWER_CYCLE_ROUND "$user_proj_name" $user_fan_pwm_bkp $user_fan_hspd_rpm_tlr $user_fan_lspd_rpm_tlr
                sleep 15

                test_result_log_file_name="$LOG_DIAG_FAN_RESULT_TMP"
                DIAG_FAN_TEST_RESULT=$PASS

                ## Parsing test items result.
                if [ -f "$test_result_log_file_name" ]; then
                    Diag_Parsing_Test_Result $DIAG_CURRENT_POWER_CYCLE_ROUND $pt_test_step "$test_result_log_file_name"

                    # Write test result to final result log file(ex:diag_burn_in_result.log).
                    read test_result_string < "$test_result_log_file_name"
                    echo "    $test_result_string" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
                    sync
                else
                    printf "[Diag Msg] %s File NOT Exist\n" "$test_result_log_file_name"
                    break
                fi

                printf "\n################################### Fan Test End ###################################\n"
                ;;

            2)  ## Storage Test
                printf "\n\n################################### Storage Test Start ###################################\n\n"

                bash ${MFG_SOURCE_DIR}/diag_component_test.sh $DIAG_CURRENT_POWER_CYCLE_ROUND "$user_test_mode" "$user_stg_mode" $user_stg_size "No stg-dev Para" "$user_stg_cns_out" "No cmp-test-time Para" "$user_oob_dut_ip" "$user_oob_target_ip" "$user_proj_name"
                sleep 3

                test_result_log_file_name="$LOG_DIAG_COMPONENT_RESULT_TMP"
                DIAG_STORAGE_TEST_RESULT=$PASS

                ## Parsing test items result.
                if [ -f "$test_result_log_file_name" ]; then
                    Diag_Parsing_Test_Result $DIAG_CURRENT_POWER_CYCLE_ROUND $pt_test_step "$test_result_log_file_name"

                    ## Write test result to final result log file(ex:diag_burn_in_result.log).
                    read test_result_string < "$test_result_log_file_name"
                    echo "    $test_result_string" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
                    sync
                else
                    printf "[Diag Error Msg] %s File NOT Exist\n" "$test_result_log_file_name"
                    break
                fi

                printf "\n################################### Storage Test End ###################################\n"
                ;;

            3)  ## Traffic Test
                for (( burn_in_round = 1; burn_in_round <= $user_burn_in_cyc_num; burn_in_round += 1 ))
                do
                    printf "\n\n################################### Burn-In Test Start ###################################\n\n"

                    if (( $user_burn_in_cyc_num >= 2 )); then
                        echo "    Current Burn-In Cycle Round : $burn_in_round" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
                    fi

                    if [[ "$user_proj_name" == "Bugatti" ]]; then
                        bash ${MFG_SOURCE_DIR}/diag_bcm_traffic_test.sh $user_tfc_mode_sel $DIAG_LINK_WAIT_TIME $user_tfc_pkt_time $DIAG_LOG_PARSE_TIME $DIAG_TRAFFIC_TEST_SFP_SPEED $user_tfc_qsfp_sp "$user_tfc_an" "$user_tfc_vl" "$user_tfc_if"    # $PEGA_TRAFFIC_TEST_SFP_SPEED no used but need to set to align parameter numbers.
                    elif [[ "$user_proj_name" == "Porsche" ]]; then
                        bash ${MFG_SOURCE_DIR}/diag_nps_traffic_test.sh $DIAG_CURRENT_POWER_CYCLE_ROUND $burn_in_round $user_tfc_mode_sel $user_tfc_pkt_time
                    elif [[ "$user_proj_name" == "Gemini" ]]; then
                        bash ${MFG_SOURCE_DIR}/diag_marvell_traffic_test.sh $user_tfc_mode_sel $DIAG_CURRENT_POWER_CYCLE_ROUND $user_tfc_pkt_time $user_tfc_if
                    fi
                    sleep 3

                    test_result_log_file_name=$LOG_DIAG_TRAFFIC_RESULT_TMP
                    DIAG_TRAFFIC_TEST_RESULT=$PASS

                    # Parsing test items result.
                    if [ -f "$test_result_log_file_name" ]; then
                        Diag_Parsing_Test_Result $burn_in_round $pt_test_step "$test_result_log_file_name"
                    else
                        printf "[Diag Error Msg] %s File NOT Exist\n" "$test_result_log_file_name"
                        break
                    fi

                    ## In the case of running only 1 round "power cycle" and "burn-in cycle".
                    ## No special case when traffic test is fail !!!

                    ## Handle some special case in first burn-in cycle round test result.
                    if (( $user_pwr_cyc_num == 1 )); then
                        ## In this case, run 1 round "power cycle" and 2~N rounds "burn-in cycle".
                        ## Special case occur in 1st round of "burn-in cycle" when traffic test fail.
                        if (( $user_burn_in_cyc_num >= 2 )); then
                            if (( $burn_in_round == 1 )) && (( $DIAG_TRAFFIC_TEST_RESULT == $FAIL )); then
                                DIAG_TRAFFIC_TEST_RESULT=$PASS
                                op_need_check_modules_plugged_status=$TRUE
                            fi
                        fi
                    else
                        ## In this case, run 2~N rounds "power cycle",
                        ## and every "power cycle" has 1~N round "burn-in cycle".
                        ## Special case occur in 1st round of "power cycle" when traffic test fail.
                        if (( $DIAG_CURRENT_POWER_CYCLE_ROUND == 1 )) && (( $burn_in_round == 1 )) && (( $DIAG_TRAFFIC_TEST_RESULT == $FAIL )); then
                            DIAG_TRAFFIC_TEST_RESULT=$PASS
                            op_need_check_modules_plugged_status=$TRUE
                        fi
                    fi

                    ## Write test result to final result log file(ex:diag_burn_in_result.log).
                    read test_result_string < "$test_result_log_file_name"
                    if (( $user_burn_in_cyc_num == 1 )); then
                        echo "    $test_result_string" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
                    else
                        echo "        $test_result_string" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
                        sleep $DIAG_PT_BURN_IN_ROUND_DELAY    # delay between every burn-in cycle round
                    fi
                    sync

                    if (( $DIAG_TRAFFIC_TEST_RESULT == $FAIL )); then
                        break   ## break burn-in loop
                    fi

                    printf "\n################################### Burn-In Test End ###################################\n"
                done
                ;;
            *)  ;;
        esac

        ## Include call hardware monitor (after fan test) and dump its log every test item finish.
        ## 20200910 Gemini special case to call hw-monitor after SDK init done, due to need I2C to light LED in SDK.
        if [[ "$user_proj_name" != "Gemini" ]] || [[ "$user_proj_name" == "Gemini" && "$pt_test_step" == "3" ]]; then
            Diag_Monitor_Process_Control $pt_test_step
        fi

        if (( $DIAG_FAN_TEST_RESULT == $FAIL )) || (( $DIAG_STORAGE_TEST_RESULT == $FAIL )) || (( $DIAG_TRAFFIC_TEST_RESULT == $FAIL )); then
            DIAG_TEST_RESULT=$FAIL
            break   ## break power cycle loop
        else
            pt_test_step=$(( $pt_test_step + 1 ))
        fi
    done    ## end while loop

    # ====================================================================================================================================================== #

    ## Kill hardware monitor process.
    ## 20200910 Gemini special case to call hw-monitor after SDK init done.
    if [[ "$user_proj_name" != "Gemini" ]]; then
        Diag_Monitor_Process_Kill 1
    fi

    ## Show power cycle result on console.
    printf "\n[Diag Msg] Power Cycle Round %d Finished !!!\n" $DIAG_CURRENT_POWER_CYCLE_ROUND

    if (( $DIAG_TEST_RESULT == $PASS )); then
        printf "           Power Cycle Result : PASS\n"
        echo "===> Power Cycle Result : PASS" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
        echo "" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"

        ## current power cycle round count 1
        DIAG_CURRENT_POWER_CYCLE_ROUND=$(( $DIAG_CURRENT_POWER_CYCLE_ROUND + 1 ))

        if (( $DIAG_CURRENT_POWER_CYCLE_ROUND > $user_pwr_cyc_num )); then
            printf "\n[Diag Msg] All Power Cycle are Finished\n"

            ## All burn-in round pass. (Turn System-Status LED Green On)
            Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON

            ## If next power cycle round > power cycle number,
            ## then turn-off burn-in flag and write to configuration file.
            sed -i "8,8d" "$DIAG_CONF_FILE_NAME"
            sed -i "8i Traffic Test Set            :   off" "$DIAG_CONF_FILE_NAME"    # Burn-In Set
        else
            ## 20200914 Add PT new request : 1st round traffic fail need to make SYSLED Amber blinking
            if (( $op_need_check_modules_plugged_status == $TRUE )); then
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_BLINK
            else
                ## Current burn-in round test pass. (Turn System-Status LED Green Blinking)
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_BLINK
            fi

            ## If next power cycle round <= power cycle number,
            ## then write next power cycle round to configuration file.
            sed -i "11,11d" "$DIAG_CONF_FILE_NAME"
            sed -i "11i Current Power Cycle Round   :   $DIAG_CURRENT_POWER_CYCLE_ROUND" "$DIAG_CONF_FILE_NAME"

            ## 20200424 add for Gemini factory production request
            if [[ "$user_proj_name" == "Gemini" ]]; then
                sync
                sleep 30

                ## 20200918 Use BDX CPLD reg4,bit1 to trigger full reset
                Mutex_Check_And_Create
                if (( $FLAG_USE_IPMI == "$TRUE" )); then
                    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
                fi

                npu_cpld_ctrl_reg_val=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_MISC_CNTL_REG ; } 2>&1 )
                write_data=$(( $npu_cpld_ctrl_reg_val & 0xfd ))
                Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_MISC_CNTL_REG $write_data

                Mutex_Clean
                if (( $FLAG_USE_IPMI == "$TRUE" )); then
                    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
                fi
            fi
            ## Add End
        fi
    elif (( $DIAG_TEST_RESULT == $FAIL )); then
        ## Final burn-in result fail. (Turn System-Status LED Amber Blink)
        Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_BLINK

        printf "           Power Cycle Result : FAIL\n"
        echo "===> Power Cycle Result : FAIL" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"
        echo "" >> "$DIAG_PT_TEST_RESULT_LOG_NAME"

        ## Turn-off burn-in flag and write to configuration file.
        sed -i "8,8d" "$DIAG_CONF_FILE_NAME"
        sed -i "8i Traffic Test Set            :   off" "$DIAG_CONF_FILE_NAME"    # Burn-In Set

        ## File the result to light next round LED if test fail.
        echo "fail" > $DIAG_BURNIN_RESULT_NOTE
        sync
    fi
    sync

    if [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
        cp $DIAG_CONF_FILE_NAME $FOLDER_PATH_EMMC
        sync
    fi
}

function Diag_Run_Thermal_Test()
{
    echo "[Diag Msg] Start Thermal test"

    cmp_test_time=$(( $user_tfc_pkt_time * 60 ))

    ## Gain Modules' Loading Watt
    printf "\n[Diag Msg] Gain Modules' Loading to %f watt\n" $user_module_watt_set
    bash ${MFG_SOURCE_DIR}/module_voltage_control.sh $user_module_watt_set

    ## Gain CPU Loading to 100%
    printf "\n[Diag Msg] Gain CPU Loading\n"
    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        cpu_cores=4
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        cpu_cores=8
    fi
    bash $MFG_SOURCE_DIR/cpu_gain_loading.sh $cpu_cores $cmp_test_time &

    ## Execute component test (eMMC+USB+SSD)
    printf "\n"
    cmp_test_para_str="0 "
    cmp_test_para_str+="${user_test_mode} "
    cmp_test_para_str+="${user_stg_mode} ${user_stg_size} ${user_stg_dev} ${DIAG_STORAGE_TEST_CNS_OUT} "
    cmp_test_para_str+="${cmp_test_time} "
    bash ${MFG_SOURCE_DIR}/diag_component_test.sh ${cmp_test_para_str}

    ## Call SDK to do traffic flooding
    printf "[Diag Msg] Calling SDK to Achieve Traffic Flooding ...\n"
    ## ! Add each project's SDK entry point here !
    if [[ "$user_proj_name" == "Gemini" ]]; then
        bash $MFG_WORK_DIR/sdk_start qsfp=$user_tfc_qsfp_sp sfp=$user_tfc_sfp_sp if=$user_tfc_if vlan=$user_tfc_vl flooding=$cmp_test_time
    elif [[ "$user_proj_name" == "Porsche" ]]; then
        ./sdk_ref
    fi
}

function Diag_Run_EMC_Test()
{
    echo "[Diag Msg] Start EMC test"

    cmp_test_time=$(( $user_tfc_pkt_time * 60 ))

    ## Execute component test (eMMC+USB + OOB)
    printf "\n"
    cmp_test_para_str="0 "
    cmp_test_para_str+="${user_test_mode} "
    cmp_test_para_str+="${user_stg_mode} ${user_stg_size} ${user_stg_dev} ${DIAG_STORAGE_TEST_CNS_OUT} "
    cmp_test_para_str+="${cmp_test_time} "
    cmp_test_para_str+="${user_oob_dut_ip} ${user_oob_target_ip} "
    bash ${MFG_SOURCE_DIR}/diag_component_test.sh ${cmp_test_para_str}

    ## Call SDK to do burn-in test
    printf "[Diag Msg] Calling SDK to Achieve Traffic Test ...\n"
    if [[ "$user_proj_name" == "Gemini" ]]; then
        bash ${MFG_SOURCE_DIR}/diag_marvell_traffic_test.sh $user_tfc_mode_sel 0 $user_tfc_pkt_time $user_tfc_if
    elif [[ "$user_proj_name" == "Porsche" ]]; then
        ./sdk_ref
    fi
}

function Diag_Run_Safety_Test()
{
    echo "[Diag Msg] Start Safety test"

    cmp_test_time=$(( $user_tfc_pkt_time * 60 ))

    ## Gain Modules' Loading Watt
    printf "\n[Diag Msg] Gain Modules' Loading to %f watt\n" $user_module_watt_set
    bash ${MFG_SOURCE_DIR}/module_voltage_control.sh $user_module_watt_set

    ## Gain CPU Loading to 100%
    printf "\n[Diag Msg] Gain CPU Loading\n"
    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        cpu_cores=4
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        cpu_cores=8
    fi
    bash $MFG_SOURCE_DIR/cpu_gain_loading.sh $cpu_cores $cmp_test_time &

    ## Execute component test (eMMC+USB+SSD)
    printf "\n"
    cmp_test_para_str="0 "
    cmp_test_para_str+="${user_test_mode} "
    cmp_test_para_str+="${user_stg_mode} ${user_stg_size} ${user_stg_dev} ${DIAG_STORAGE_TEST_CNS_OUT} "
    cmp_test_para_str+="${cmp_test_time} "
    bash ${MFG_SOURCE_DIR}/diag_component_test.sh ${cmp_test_para_str}

    ## Call SDK to do traffic flooding
    printf "[Diag Msg] Calling SDK to Achieve Traffic Test ...\n"
    ## ! Add each project's SDK entry point here !
    if [[ "$user_proj_name" == "Gemini" ]]; then
        bash ${MFG_SOURCE_DIR}/diag_marvell_traffic_test.sh $user_tfc_mode_sel 0 $user_tfc_pkt_time $user_tfc_if
    elif [[ "$user_proj_name" == "Porsche" ]]; then
        ./sdk_ref
    fi
}

function Diag_Run_QTR_Test()
{
    echo "[Diag Msg] Start QTR test"

    ## Call SDK to prepare test with IXIA.
    if [[ "$user_proj_name" == "Gemini" ]]; then
        bash ${MFG_SOURCE_DIR}/gemini_sdk_start.sh qsfp=$user_tfc_qsfp_sp sfp=$user_tfc_sfp_sp if=$user_tfc_if vlan=$user_tfc_vl fec=$user_tfc_fec
    elif [[ "$user_proj_name" == "Porsche" ]]; then
        ./sdk_ref
    fi
}

function Diag_Run_FW_UPGRADE_Test()
{
    echo "[Diag Msg] Start FW upgrade regression test"

    bash ${MFG_SOURCE_DIR}/fw_regression_test.sh
}

function Diag_Option_Handler()
{
    # EDVT Option Test
    # --edvt-test-set on --pwr-cyc-num 8 --edvt-sel-test 1 --edvt-test-time 360 --stress-vol-set -5 --stg-mode 2 --stg-size 256 --stg-dev 2 --oob-dut-ip 192.168.11.11 --oob-target-ip 192.168.22.22 --pcie-test-rnd-t 120 --tfc-mode 2 --tfc-link-wait-t 3 --tfc-pkt-loss-tol 10 --tfc-sfp-sp 10 --tfc-qsfp-sp 50 --tfc-an on --tfc-vl off --tfc-if copper

    # PT Option Test
    # --burn-in-set on --pwr-cyc-num 8 --burn-in-cyc-num 7 --fan-pwm-bkp 50 --fan-hspd-rpm-tlr 10 --fan-lspd-rpm-tlr 15 --stg-mode 2 --stg-size 1024 --stg-cns-out yes --tfc-mode 2 --tfc-link-wait-t 3 --tfc-pkt-t 20 --tfc-pkt-loss-tol 3 --tfc-sfp-sp 10 --tfc-qsfp-sp 50 --tfc-an on --tfc-vl off --tfc-if copper

    option="$1"
    para=$2

    case "$option" in
        "--rm-log")
            if [[ "$para" == "edvt" ]]; then
                Diag_Remove_Old_Log "EDVT"
            else
                Diag_Remove_Old_Log "PT"
            fi
            ;;
        # --------------------------------------------------------------------------- #
        "--test-mode-set")
            para_update_flag=$FALSE
            unknown_option_flag=$FALSE
            if [[ "$para" == "emc" ]]; then
                user_test_mode="EMC"
            elif [[ "$para" == "qtr" ]]; then
                user_test_mode="QTR"
            elif [[ "$para" == "safety" ]]; then
                user_test_mode="SAFETY"
            elif [[ "$para" == "thermal" ]]; then
                user_test_mode="THERMAL"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                unknown_option_flag=$TRUE
            fi
            if [[ "$unknown_option_flag" != "$TRUE" ]]; then
                sed -i "4,4d" "$DIAG_CONF_FILE_NAME"
                sed -i "4i Current Test Mode :   $user_test_mode" "$DIAG_CONF_FILE_NAME"
            fi
            ;;
        # --------------------------------------------------------------------------- #
        # For EDVT
        "--edvt-test-set")
            if [[ "$para" == "on" ]]; then
                user_edvt_test_set="on"

                ## When user set "--edvt-test-set on",
                ## reset "DIAG_CURRENT_POWER_CYCLE_ROUND" variable to 1 to run new power cycle.
                DIAG_CURRENT_POWER_CYCLE_ROUND=1
            elif [[ "$para" == "off" ]]; then
                user_edvt_test_set="off"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] edvt-test-set ---> %s\n" "$user_edvt_test_set"
                fi
            ;;
        "--edvt-sel-test")
            case $para in
                1)  user_edvt_sel_test="4C Component Test"                      ;;
                2)  user_edvt_sel_test="4C Internal Traffic Test"               ;;
                3)  user_edvt_sel_test="4C Component + Internal Traffic Test"   ;;
                4)  user_edvt_sel_test="4C Component + External Traffic Test"   ;;
                5)  user_edvt_sel_test="External Traffic Test"   ;;
                *)
                    printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                    para_update_flag=$FALSE
                    ;;
            esac
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] edvt-sel-test ---> %d [%s]\n" $2 "$user_edvt_sel_test"
                fi
            ;;
        "--edvt-test-time")
            if (( $para >= 0 )); then
                user_edvt_test_time=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] edvt-test-time ---> %d\n" $user_edvt_test_time
                fi
            ;;
        # --------------------------------------------------------------------------- #
        # For PT
        "--burn-in-set")
            if [[ "$para" == "on" ]]; then
                user_burn_in_set="on"

                ## When user set "--burn-in-set on",
                ## reset "DIAG_CURRENT_POWER_CYCLE_ROUND" variable to 1 to run new power cycle.
                DIAG_CURRENT_POWER_CYCLE_ROUND=1
            elif [[ "$para" == "off" ]]; then
                user_burn_in_set="off"
            elif [[ "$para" == "pt_loopback" ]]; then # Modified in option tfc-mode
                user_burn_in_set="pt_loopback"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] burn-in-set ---> %s\n" "$user_burn_in_set"
                fi
            ;;
        "--pt-sel-test")
            case $para in
                1)  user_edvt_sel_test="Burn-In"
                    user_tfc_mode="PT-BurnIn"
                    ;;
                2)  user_edvt_sel_test="4C Component + Internal Traffic Test"
                    user_tfc_mode="PT-4C"
                    ;;
                *)
                    printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                    para_update_flag=$FALSE
                    ;;
            esac
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] edvt-sel-test ---> %d [%s]\n" $2 "$user_edvt_sel_test"
                fi
            ;;
        "--pwr-cyc-num")
            if (( $para > 0 )); then
                user_pwr_cyc_num=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] pwr-cyc-num ---> %d\n" $user_pwr_cyc_num
                fi
            ;;
        "--burn-in-cyc-num")
            if (( $para > 0 )); then
                user_burn_in_cyc_num=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] burn-in-cyc-num ---> %d\n" $user_burn_in_cyc_num
                fi
            ;;
        # --------------------------------------------------------------------------- #
        # For Thermal
        "--thermal-test-set")
            if [[ "$para" == "on" ]]; then
                user_thermal_test_set="on"
            elif [[ "$para" == "off" ]]; then
                user_thermal_test_set="off"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] thermal-test-set ---> %s\n" "$user_thermal_test_set"
                fi
            ;;
        # --------------------------------------------------------------------------- #
        # For EMC
        "--emc-test-set")
            if [[ "$para" == "on" ]]; then
                user_emc_test_set="on"
            elif [[ "$para" == "off" ]]; then
                user_emc_test_set="off"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] emc-test-set ---> %s\n" "$user_emc_test_set"
                fi
            ;;
        # --------------------------------------------------------------------------- #
        # For Safety
        "--safety-test-set")
            if [[ "$para" == "on" ]]; then
                user_safety_test_set="on"
            elif [[ "$para" == "off" ]]; then
                user_safety_test_set="off"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] safety-test-set ---> %s\n" "$user_safety_test_set"
                fi
            ;;
        # --------------------------------------------------------------------------- #
        # For QTR
        "--qtr-test-set")
            if [[ "$para" == "on" ]]; then
                user_qtr_test_set="on"
            elif [[ "$para" == "off" ]]; then
                user_qtr_test_set="off"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] qtr-test-set ---> %s\n" "$user_qtr_test_set"
                fi
            ;;
        # --------------------------------------------------------------------------- #
        # For FW_REGRESSIOM
        "--fw-test-set")
            if [[ "$para" == "on" ]]; then
                user_fw_test_set="on"
            elif [[ "$para" == "off" ]]; then
                user_fw_test_set="off"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] fw-test-set ---> %s\n" "$user_fw_test_set"
                fi
            ;;
        "--fw-test-round-set")
            if (( $para < 5  || ( $para % 5 != 0 ) )); then
                printf "[Diag Error Msg] Invalid Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            else
                user_fw_test_round="$para"
            fi
            ;;
        # --------------------------------------------------------------------------- #
        "--stress-vol-set")     # For EDVT 4-corner test voltage (+/- 5%) setting.
            if [[ "$para" == "positive" ]] || [[ "$para" == "negative" ]] || [[ "$para" == "normal" ]]; then
                user_vol_set="$para"
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] stress-vol-set ---> %s\n" "$user_vol_set"
                fi
            ;;
        "--load-watt-set")     # For moduelse loading setting.
            if [[ "$para" == "1.0" ]] || [[ "$para" == "1.5" ]] || [[ "$para" == "2.0" ]] || [[ "$para" == "2.5" ]] || [[ "$para" == "3.0" ]] || [[ "$para" == "3.5" ]] || [[ "$para" == "4.0" ]] || [[ "$para" == "4.5" ]] || [[ "$para" == "5.0" ]]; then
                user_module_watt_set="$para"
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] load-watt-set ---> %s\n" "$user_module_watt_set"
                fi
            ;;
        # --------------------------------------------------------------------------- #
        "--fan-pwm-bkp")        # Fan Test Parameter : fan PWM break-point setting
            ## Because high and low fan PWM(speed) use different fan R.P.M tolerance,
            # need a fan PWM break-point setting to separate.
            # high-speed fan PWM use high-speed fan RPM tolerance.
            if (( $para >= 0 )) && (( $para <= 100 )); then
                user_fan_pwm_bkp=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] fan-pwm-bkp ---> %d\n" $user_fan_pwm_bkp
                fi
            ;;
        "--fan-hspd-rpm-tlr")   # Fan Test Parameter: fan high-speed r.p.m tolerance setting
            if (( $para >= 0 )) && (( $para <= 100 )); then
                user_fan_hspd_rpm_tlr=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] fan-hspd-rpm-tlr ---> %d\n" $user_fan_hspd_rpm_tlr
                fi
            ;;
        "--fan-lspd-rpm-tlr")   # Fan Test Parameter: fan low-speed r.p.m tolerance setting
            if (( $para >= 0 )) && (( $para <= 100 )); then
                user_fan_lspd_rpm_tlr=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] fan-lspd-rpm-tlr ---> %d\n" $user_fan_lspd_rpm_tlr
                fi
            ;;
        # --------------------------------------------------------------------------- #
        "--stg-mode")   # Storage Test Parameter: storage test mode selection
            if (( $para == 1 )); then
                user_stg_mode="parallel"
            elif (( $para == 2 )); then
                user_stg_mode="sequential"
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] stg-mode ---> %d [%s]\n" $2 "$user_stg_mode"
                fi
            ;;
        "--stg-size")   # Storage Test Parameter: test file size setting
            if (( $para % 2 == 0 )); then
                user_stg_size=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] stg-size ---> %d \n" $user_stg_size
                fi
            ;;
        "--stg-dev")    # Storage Test Parameter: device under test selection
            case $para in
                1)  user_stg_dev="DRAM-eMMC"            ;;
                2)  user_stg_dev="DRAM-eMMC-USB"        ;;
                3)  user_stg_dev="DRAM-eMMC-USB-SSD"    ;;
                4)  user_stg_dev="DRAM-eMMC-USB-SSD-SPI";;
                *)
                    printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                    para_update_flag=$FALSE
                    ;;
            esac
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] stg-dev ---> %d [%s]\n" $2 "$user_stg_dev"
                fi
            ;;
        "--stg-cns-out")    # Storage Test Parameter: test log output on console selection
            if [[ "$para" == "yes" ]] || [[ "$para" == "no" ]]; then
                user_stg_cns_out="$para"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] stg-cns-out ---> %s\n" "$user_stg_cns_out"
                fi
            ;;
        # --------------------------------------------------------------------------- #
        "--oob-dut-ip")     # OOB Ping Test Parameter: Device Under Test IP setting
            # maybe need to ckeck ip here
            user_oob_dut_ip="$para"
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] oob-dut-ip ---> %s\n" "$user_oob_dut_ip"
                fi
            ;;
        "--oob-target-ip")  # OOB Ping Test Parameter: Target IP setting
            # maybe need to ckeck ip here
            user_oob_target_ip="$para"
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] oob-target-ip ---> %s\n" "$user_oob_target_ip"
                fi
            ;;
        # --------------------------------------------------------------------------- #
        "--pcie-test-rnd-t")    # PCIe Bus R/W Test Parameter: test round setting
            if (( $para > 0 )); then
                user_pcie_test_rnd_time=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] pcie-test-rnd-t ---> %d\n" $user_pcie_test_rnd_time
                fi
            ;;
        # --------------------------------------------------------------------------- #
        "--tfc-mode")
            case $para in
                1)  user_tfc_mode="EDVT"        ;;
                2)  user_tfc_mode="PT-PreTest"  ;;
                3)  user_tfc_mode="PT-BurnIn"   ;;
                *)
                    printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                    para_update_flag=$FALSE
                    ;;
            esac
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-mode ---> %d [%s]\n" $2 "$user_tfc_mode"
                fi
            ;;
        "--tfc-link-wait-t")
            if (( $para >= 0 )); then
                user_tfc_link_wait_time=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-link-wait-t ---> %d\n" $user_tfc_link_wait_time
                fi
            ;;
        "--tfc-pkt-t")  # Only PT mode can set this option.
            if (( $para > 0 )); then
                user_tfc_pkt_time=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-pkt-t ---> %d\n" $user_tfc_pkt_time
                fi
            ;;
        "--tfc-pkt-loss-tol")
            if (( $para >= 0 )); then
                user_tfc_pkt_loss_tol=$para
            else
                printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-pkt-loss-tol ---> %d\n" $user_tfc_pkt_loss_tol
                fi
            ;;
        # --------------------------------------------------------------------------- #
        "--tfc-sfp-sp")
            case $para in
                10) user_tfc_sfp_sp=10  ;;
                25) user_tfc_sfp_sp=25  ;;
                *)
                    printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                    para_update_flag=$FALSE
                ;;
            esac
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-sfp-sp ---> %d\n" $user_tfc_sfp_sp
                fi
            ;;
        "--tfc-qsfp-sp")
            case $para in
                10)     user_tfc_qsfp_sp=10  ;;
                25)     user_tfc_qsfp_sp=25  ;;
                40)     user_tfc_qsfp_sp=40  ;;
                50)     user_tfc_qsfp_sp=50  ;;
                100)    user_tfc_qsfp_sp=100 ;;
                *)
                    printf "[Diag Error Msg] Illegal Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                    para_update_flag=$FALSE
                ;;
            esac
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-qsfp-sp ---> %d\n" $user_tfc_qsfp_sp
                fi
            ;;
        "--tfc-qsfpdd-sp")
            if [[ "$para" == "400g-pam4" ]]; then
                user_tfc_qsfpdd_sp="$para"
            fi
            ;;
        "--tfc-an")
            if [[ "$para" == "off" ]]; then
                user_tfc_an="off"
            elif [[ "$para" == "on" ]]; then
                user_tfc_an="on"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-an ---> %s\n" "$user_tfc_an"
                fi
            ;;
        "--tfc-vl")
            if [[ "$para" == "off" ]]; then
                user_tfc_vl="off"
            elif [[ "$para" == "on" ]]; then
                user_tfc_vl="on"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-vl ---> %s\n" "$user_tfc_vl"
                fi
            ;;
        "--tfc-if")
            case "$para" in
                "DAC")      user_tfc_if="DAC"       ;;
                "fiber")    user_tfc_if="fiber"     ;;
                "mix")      user_tfc_if="mix"       ;;
                "mix-1")    user_tfc_if="mix-1"     ;;
                "mix-2")    user_tfc_if="mix-2"     ;;
                "lbm")      user_tfc_if="lbm"       ;;
                *)
                    printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"--tfc-if\"\n" "$para"
                    para_update_flag=$FALSE
                ;;
            esac
                if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                    printf "[User Select] tfc-if ---> %s\n" "$user_tfc_if"
                fi
            ;;
        "--tfc-fec")
            if [[ "$para" == "off" ]]; then
                user_tfc_fec="off"
            elif [[ "$para" == "on" ]]; then
                user_tfc_fec="on"
            else
                printf "[Diag Error Msg] Unknown Parameter \"%s\" of Option \"%s\"\n" "$para" "$option"
                para_update_flag=$FALSE
            fi
            ;;
        #"--tfc-tx")
        #    ;;
        #"--tfc-rcload")
        #    ;;
        # --------------------------------------------------------------------------- #
        *)
            printf "[Diag Error Msg] Unknown Option \"%s\"\n" $1
            para_update_flag=$FALSE
            unknown_option_flag=$TRUE
            ;;
    esac

    #if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
    #    printf "\n"
    #fi
}

function Diag_Monitor_Process_Control()
{
    test_step=$1

    DIAG_HW_MONITOR_LOG_NAME=${LOG_PATH_HWMONITOR}/hw_monitor_$DIAG_CURRENT_POWER_CYCLE_ROUND.log

    # Run hardware monitor under background after "fan test".
    # Remember to stop it every burn-in round.
    if (( $test_step == 1 )); then
        #printf "\n[Debug] Run HW-Monitor and Put it under Background\n"

        # Use "bash" to call child process, it will independent to parent process.
        bash ${MFG_WORK_DIR}/hw_monitor 0 20 $DIAG_CURRENT_POWER_CYCLE_ROUND &
        #sleep 3
    fi

    file_not_exist_cnt=1
    while true;
    do
        if [ -f "$DIAG_HW_MONITOR_LOG_NAME" ]; then
            if [[ ! -f "$I2C_MUTEX_NODE" ]] && [[ -f "$HW_MONITOR_DONE_NODE" ]]; then      ## nobody use I2C bus
                #echo "[Debug] Start Dump Hardware-Monitor"

                touch $I2C_MUTEX_NODE
                sleep 1

                printf "\n\n****************************** Show Hardware Monitor Start ******************************\n\n"

                keyline="Hardware Monitor Information:"

                for (( i = 1; i <= 4; i += 1 ))
                do
                    curr_line_num=$(( 50 * $i ))
                    # nl "$DIAG_HW_MONITOR_LOG_NAME" | tail -n $curr_line_num | grep "$keyline" | awk '{print $1}' ) ))
                    keystr=$( tail -n $curr_line_num "$DIAG_HW_MONITOR_LOG_NAME" | grep -n "$keyline" )

                    if [ -n "$keystr" ]; then
                        #echo "$keystr"

                        keystr_len=${#keystr}
                        #echo "keystr_len ---> $keystr_len"

                        for (( j = 0; j <= $keystr_len; j += 1 ))
                        do
                            if [[ ${keystr:j:1} == ":" ]]; then
                                shift_line_num=$(( ${keystr:0:$j} ))
                                    #echo "shift_line_num   ---> $shift_line_num"
                                total_line_num=$(( $( wc $DIAG_HW_MONITOR_LOG_NAME | awk '{print $1}' ) ))
                                    #echo "total_line_num   ---> $total_line_num"
                                if (( $total_line_num < $curr_line_num )); then
                                    start_line_index=$(( $shift_line_num - 1 ))
                                else
                                    start_line_index=$(( $total_line_num - $curr_line_num + $shift_line_num - 1 ))
                                fi
                                    #echo "curr_line_num    ---> $curr_line_num"
                                    #echo "start_line_index ---> $start_line_index"

                                # "sed -n n1,n2p" dump log from n1 to n2
                                sed_action_cmd=$start_line_index',$p'
                                #echo "sed_action_cmd ---> $sed_action_cmd"
                                sed -n "$sed_action_cmd" "$DIAG_HW_MONITOR_LOG_NAME"
                                break
                            fi
                        done
                        sync
                        break
                    fi
                done

                printf "\n\n****************************** Show Hardware Monitor End ******************************\n\n"

                if [ -f "$HW_MONITOR_DONE_NODE" ]; then
                    rm $HW_MONITOR_DONE_NODE
                fi

                if [ -f "$I2C_MUTEX_NODE" ]; then
                    rm $I2C_MUTEX_NODE
                fi
                sleep 1
                #echo "[Debug] End Dump Hardware-Monitor"

                break
            else
                #echo "[Debug] This is Dump Hardware-Monitor. Wait key..."
                sleep 1
            fi
        else
            sleep $DIAG_FILE_EXIST_CHECK_WAIT_TIME

            #echo "[Debug] [$file_not_exist_cnt] Wait Hardware Monitor Log ..."
            if (( $file_not_exist_cnt > $DIAG_FILE_EXIST_CHECK_CNT )); then
                printf "[Diag Error Msg] %s File NOT Exist\n" "$DIAG_HW_MONITOR_LOG_NAME"
                sync
                break
            fi

            file_not_exist_cnt=$(( $file_not_exist_cnt + 1 ))
        fi
    done    # end dump hardware-monitor log while loop
}

function Diag_Monitor_Process_Kill()
{
    proc_sel=$1

    #echo "[Debug] Diag_Monitor_Process_Kill"
    #time=$( date +%H:%M:%S )
    #echo "[Debug] Current Time       ---> $time"

    if (( $proc_sel == 1 )); then
        proc_name="hw_monitor"
    fi

    proc_status=$( ps | grep $proc_name | grep -v "grep" )
    #echo "[Debug] \"$proc_name\" Process Status --->"
    #echo "$proc_status"

    pvid=$( ps | grep $proc_name | grep -v "grep" | awk '{print $1}' )
    #echo "[Debug] [before] pvid ---> $pvid"

    # If process is exist, then kill it.
    if [ ! -z "$pvid" ]; then
        #echo "[Debug] Kill \"$proc_name\" Process..."

        disown $pvid
        kill -15 $pvid

        #pvid=$( ps | grep $proc_name | grep -v "grep" | awk '{print $1}' )
        #echo "[Debug] [after] pvid ---> $pvid"
        #if [ -z "$pvid" ]; then
        #    echo "[Debug] \"$proc_name\" Process has been Killed"
        #fi
    fi

    sleep 1

    # Remove "i2c-bus-mutex" after kill the process.
    if [ -f "$I2C_MUTEX_NODE" ]; then
        #echo "[Debug] Remove i2c-bus-mutex"
        rm $I2C_MUTEX_NODE
        #echo "[Debug] Show Folder"
        #ls /tmp
    fi
}

function Diag_Remove_Old_Log()
{
    curr_test_mode="$1"

    echo ''
    echo "[Diag Msg] Show Folder Before"
    ls -l "$LOG_PATH_HOME"

    if [[ "$curr_test_mode" == "EDVT" ]]; then
        ## Remove Storage test log folder.
        if [ -d "$LOG_PATH_STORAGE" ]; then
            printf "[Diag Msg] Remove Old Storage Test Log Folder Contents.\n"
            rm -rf $LOG_PATH_STORAGE/*
        fi

        ## Remove hardware monitor log folder.
        if [ -d "$LOG_PATH_HWMONITOR" ]; then
            printf "[Diag Msg] Remove Old Hardware Monitor Log Folder Contents.\n"
            rm -rf $LOG_PATH_HWMONITOR/*
        fi

        ## Remove I2C test log folder.
        if [ -d "$LOG_PATH_I2C" ]; then
            printf "[Diag Msg] Remove Old I2C Test Log Folder Contents.\n"
            rm -rf $LOG_PATH_I2C/*
        fi

        ## Remove OOB test log folder.
        if [ -d "$LOG_PATH_OOB" ]; then
            printf "[Diag Msg] Remove Old OOB Test Log Folder Contents.\n"
            rm -rf $LOG_PATH_OOB/*
        fi
        ## Remove version check log
        if [ -f "$LOG_DIAG_VERSION_CHECK" ]; then
            printf "[Diag Msg] Remove Old Version Check Log.\n"
            rm -f $LOG_DIAG_VERSION_CHECK
        fi

    elif [[ "$curr_test_mode" == "PT" ]]; then
        ## Remove Fan test log folder.
        if [ -d "$LOG_PATH_FAN" ]; then
            printf "[Diag Msg] Remove Old Fan Test Log Folder Contents.\n"
            rm -rf $LOG_PATH_FAN/*
        fi

        ## Remove Storage test log folder.
        if [ -d "$LOG_PATH_STORAGE" ]; then
            printf "[Diag Msg] Remove Old Storage Test Log Folder Contents.\n"
            rm -rf $LOG_PATH_STORAGE/*
        fi

        ## Remove hardware monitor log folder.
        if [ -d "$LOG_PATH_HWMONITOR" ]; then
            printf "[Diag Msg] Remove Old Hardware Monitor Log Folder Contents.\n"
            rm -rf $LOG_PATH_HWMONITOR/*
        fi

        # Remove PT mode burn-in test result log.
        if [ -f "$DIAG_PT_TEST_RESULT_LOG_NAME" ]; then
            printf "[Diag Msg] Remove Old Burn-In Result File\n"
            rm $DIAG_PT_TEST_RESULT_LOG_NAME
        fi

        find ${LOG_PATH_HOME}/ -type f -name "diag_burn_in_result_*.log" -exec rm -f {} \;

        ## Remove system LED check file.
        if [[ -f "$DIAG_BURNIN_RESULT_NOTE" ]]; then
            printf "[Diag Msg] Remove Old Burn-In Result LED check File\n"
            rm $DIAG_BURNIN_RESULT_NOTE
        fi

        ## Remove I2C test log folder.
        if [ -d "$LOG_PATH_I2C" ]; then
            printf "[Diag Msg] Remove Old I2C Test Log Folder Contents.\n"
            rm -rf $LOG_PATH_I2C/*
        fi

    fi

    ## Remove tmp log files.
    if [[ -f "$LOG_DIAG_TRAFFIC_RESULT_TMP" ]]; then
        rm $LOG_DIAG_TRAFFIC_RESULT_TMP
    fi
    if [[ -f "$LOG_DIAG_COMPONENT_RESULT_TMP" ]]; then
        rm $LOG_DIAG_COMPONENT_RESULT_TMP
    fi
    if [[ -f "$LOG_DIAG_FAN_RESULT_TMP" ]]; then
        rm $LOG_DIAG_FAN_RESULT_TMP
    fi
    if [[ -f "$LOG_DIAG_I2C_RESULT_TMP" ]]; then
        rm $LOG_DIAG_I2C_RESULT_TMP
    fi

    ## Remove MAC test log folder.
    if [ -d "$LOG_PATH_MAC" ]; then
        printf "[Diag Msg] Remove Old MAC Test Log Folder Contents.\n"
        rm -rf $LOG_PATH_MAC/*
    fi

    sync

    echo "[Diag Msg] Show Folder After"
    ls -l "$LOG_PATH_HOME"

}

# ======================================================================================================================================= #

### Main Function ###

if [ -z "$1" ]; then
    # No option, parsing configuration file and decide whether to run test or not.

    printf "\n[MFG] Diagnostic Test\n"

    if [ -f "$DIAG_CONF_FILE_NAME" ]; then
        # If diagnostic test configuration file is "exist",
        # then parsing the configuration file and assign parameter value.

        printf "\n"
        printf "[MFG] Parsing configuration file and set parameters \n"
        printf "      according to configuration file ...\n"
        Diag_Config_File_Parsing

        if [[ "$user_test_mode" == "EDVT" ]]; then
            if [[ "$user_edvt_test_set" == "on" ]]; then
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_ON
                Diag_Run_EDVT_Test
            elif [[ "$user_edvt_test_set" == "off" ]]; then
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
                printf "\n[Diag Msg] EDVT Test Flag is Off\n"
            fi
        elif [[ "$user_test_mode" == "PT" ]]; then
            if [[ "$user_burn_in_set" == "on" ]] || [[ "$user_burn_in_set" == "pt_loopback" ]]; then
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_ON
                if [[ "$user_edvt_sel_test" == "4C Component + Internal Traffic Test" ]]; then
                    Diag_Run_PT_4C_Test
                else
                    Diag_Run_PT_BurnIn_Test
                fi
            elif [[ "$user_burn_in_set" == "off" ]]; then
                printf "\n[Diag Msg] Burn-In Flag is Off\n\n"
                ## Light system LED depends on last round result.
                result=$( { cat $DIAG_BURNIN_RESULT_NOTE ; } 2>&1 )
                if [[ "$result" == "fail" ]]; then
                    Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_BLINK
                else
                    Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
                fi
                ## Add End
            fi
        elif [[ "$user_test_mode" == "THERMAL" ]]; then
            if [[ "$user_thermal_test_set" == "on" ]]; then
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_ON
                Diag_Run_Thermal_Test
            elif [[ "$user_thermal_test_set" == "off" ]]; then
                printf "\n[Diag Msg] Thermal Test Flag is Off\n\n"
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
            fi
        elif [[ "$user_test_mode" == "EMC" ]]; then
            if [[ "$user_emc_test_set" == "on" ]]; then
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_ON
                Diag_Run_EMC_Test
            elif [[ "$user_emc_test_set" == "off" ]]; then
                printf "\n[Diag Msg] EMC Test Flag is Off\n\n"
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
            fi
        elif [[ "$user_test_mode" == "SAFETY" ]]; then
            if [[ "$user_safety_test_set" == "on" ]]; then
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_ON
                Diag_Run_Safety_Test
            elif [[ "$user_safety_test_set" == "off" ]]; then
                printf "\n[Diag Msg] Safety Test Flag is Off\n\n"
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
            fi
        elif [[ "$user_test_mode" == "QTR" ]]; then
            if [[ "$user_qtr_test_set" == "on" ]]; then
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_ON
                Diag_Run_QTR_Test
            elif [[ "$user_qtr_test_set" == "off" ]]; then
                printf "\n[Diag Msg] QTR Test Flag is Off\n\n"
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
            fi
        elif [[ "$user_test_mode" == "FW_REGRESSION" ]]; then
            if [[ "$user_fw_test_set" == "on" ]]; then
                if [ ! -f $DIAG_FW_REGRESSION_ROUNDCHECK_FILE ];then
                    roundCheck_confirm=1
                else
                    roundCheck_confirm=$({ cat $DIAG_FW_REGRESSION_ROUNDCHECK_FILE ; } 2>&1 )
                fi

                if (( $roundCheck_confirm != $user_fw_test_round )); then
                    Diag_System_LED_Status $DIAG_SYS_LED_CASE_AMBER_ON
                    Diag_Run_FW_UPGRADE_Test
                else
                    printf "\n[Diag Msg] FW Regression Test is Finished !\n\n"
                    Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
                fi
            elif [[ "$user_fw_test_set" == "off" ]]; then
                printf "\n[Diag Msg] FW Regression Test Flag is Off\n\n"
                Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
            fi
        else
            Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON
        fi
    else
        # If diagnostic test configuration file is NOT "exist",
        # then generate the configuration file and reset parameters to default
        # (according to selected test mode).

        printf "\n"
        printf "[Diag Error Msg] Cannot find configuration file !!!\n"
        printf "Please use command \"./diag_test --rst-conf [Project_Name] [edvt/pt/thermal/emc/safety/qtr]\" to\n"
        printf "generate corresponding configuration file.\n"
        printf "\n"
    fi

elif [[ "$1" == "--show" ]] || [[ "$1" == "-s" ]]; then
    Diag_Show_Info $2
    shift 2

elif [[ "$1" == "--rst-conf" ]]; then
    if [[ "$2" == "Mercedes3" ]] ||
       [[ "$2" == "Porsche" ]] ||
       [[ "$2" == "Bugatti" ]] ||
       [[ "$2" == "Jaguar" ]] ||
       [[ "$2" == "Aston" ]] ||
       [[ "$2" == "Gemini" ]]; then
        user_proj_name="$2"

        if [[ "$3" == "edvt" ]] || [[ "$3" == "pt" ]] || [[ "$3" == "thermal" ]] || [[ "$3" == "emc" ]] || [[ "$3" == "safety" ]] || [[ "$3" == "qtr" ]] || [[ "$3" == "fw_regression" ]]; then
            if [[ "$3" == "edvt" ]]; then
                user_test_mode="EDVT"
            elif [[ "$3" == "pt" ]]; then
                user_test_mode="PT"
            elif [[ "$3" == "thermal" ]]; then
                user_test_mode="THERMAL"
            elif [[ "$3" == "emc" ]]; then
                user_test_mode="EMC"
            elif [[ "$3" == "safety" ]]; then
                user_test_mode="SAFETY"
            elif [[ "$3" == "qtr" ]]; then
                user_test_mode="QTR"
            elif [[ "$3" == "fw_regression" ]]; then
                user_test_mode="FW_REGRESSION"
            fi

            printf "\n"
            printf "[Diag Msg] Generate configuration file according to current test mode ...\n"
            printf "           User Select (Project_Name, Test_Mode) ---> (%s, %s)\n" "$user_proj_name" "$user_test_mode"
            printf "           Please wait ...\n"
            #Diag_Config_File_Reset_Default "$user_proj_name" "$user_test_mode"
            Diag_Parameter_Default_Init "$user_test_mode"
            Diag_Config_File_Update
            printf "[Diag Msg] Finished.\n"
            printf "\n"
            shift 3
        else
            printf "\n"
            printf "[Diag Error Msg] Unknown Test Mode < %s >\n" "$3"
            printf "\n"
        fi

            if (( $DBG_PRINT_PARSE_USER_CMD == $TRUE )); then
                printf "[User Select] rst-conf ---> %s, %s\n" "$user_proj_name" "$user_test_mode"
            fi
    else
        printf "\n"
        printf "[Diag Error Msg] Unknown Project Name < %s >\n" "$2"
        printf "\n"
    fi

    ## Reset to default status.
    if [[ -f "$DIAG_BURNIN_RESULT_NOTE" ]]; then
        rm $DIAG_BURNIN_RESULT_NOTE
    fi
    Diag_System_LED_Status $DIAG_SYS_LED_CASE_GREEN_ON

else # Other Option
    # Parsing configuration file.
    # Set parameter which NOT assign by user according to configuration file.
    if [ -f "$DIAG_CONF_FILE_NAME" ]; then
        printf "\n"
        printf "[Diag Msg] Waiting parsing configuration file ...\n"

        #Diag_Parameter_Default_Init "$user_test_mode"
        Diag_Config_File_Parsing

        para_update_flag=$TRUE
        unknown_option_flag=$FALSE

        while true;
        do
            Diag_Option_Handler $1 $2
            shift 2

            if [ -z "$1" ]; then
                break
            elif (( $unknown_option_flag == $TRUE )); then
                break
            fi
        done

        if (( $para_update_flag == $TRUE )); then
            printf "\n"
            printf "[Diag Msg] Update parameters and write to configuration file ...\n"
            printf "           Please wait ...\n"

            # Update the configuration file.
            # Write new parameter setting to configuration file.
            Diag_Config_File_Update
            printf "[Diag Msg] Finished.\n"

            printf "[Diag Msg] The parameter setting will effective in next round test.\n"
            printf "           Please re-run diag_test.sh or do power-on reset.\n"
            printf "\n"

            # Debug
            #DBG_PRINT_PARSE_CONF=1
            #Diag_Config_File_Parsing
        fi
    else
        printf "\n"
        printf "[Diag Error Msg] Cannot find configuration file !!!\n"
        printf "Please use command \"./diag_test --rst-conf [ProjectName] [edvt/pt]\" to\n"
        printf "generate corresponding configuration file.\n"
        printf "\n"
    fi
fi
