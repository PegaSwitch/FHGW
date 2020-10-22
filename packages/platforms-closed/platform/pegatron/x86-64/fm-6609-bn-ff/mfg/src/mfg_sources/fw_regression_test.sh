#!/bin/bash

## For FW upgrade/downgrade test, Porsche2/Bugatti2/Jaguar/Gemini
# 'fw_need_upgrade' is a return value to fw_regresstion_test.sh , default value is 0x00;
#  [0]=BDX_CPLD ; [1]=DNV_MCU ; [2]=MB_MCU ; [3]=FB_MCU ; [4]=MB_CPLD_A ; [5]=MB_CPLD_B ; [6]=MB_CPLD_C ;

source /home/root/mfg/mfg_sources/platform_detect.sh

TOTAL_TEST_ROUND=2000      ## SW can manually change here.

cpld_need_upgrade=0        ## this flag is for reset use
action_delay=200000
log_file="$LOG_PATH_HOME/FW_upgrade_regression_Test.log"

roundCheck_filePath="$LOG_PATH_HOME/roundCheck"                     ### "/home/root/roundCheck" is for a same MFG (no MFG NOS upgrade)
roundCheck_bkp_filePath="$LOG_PATH_HOME/roundCheck_bkp"
spimd5Check_filePath="$LOG_PATH_STORAGE/spi_md5test.log"
versionCheck_filePath="/tmp/version.txt"
spiCheck_filePath="/tmp/spiCheck.txt"
cpldCheck_filePath="/tmp/cpldCheck.txt"
mcuCheck_filePath="/tmp/mcuCheck.txt"
pktCheck_filePath="/tmp/pega_traffic_test_result.log"

## per power cycle time, there are 5 times (for BDX) / 4 times (for DNV) to boot up to rootfs.
if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
    TOTAL_BOOTUP_PERCYCLE=4
elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    TOTAL_BOOTUP_PERCYCLE=5
else
    echo " ## Not support DUT, will directly quit this test now."
    exit 1
fi

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
        ipmi_value_toHex=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 2)))" ; } 2>&1 )    # orig value format is " XX" , so just get XX then transform as 0xXX format.
        echo $ipmi_value_toHex    # this line is to make return with value 0xXX
        return
    fi
}

### version check
function Upgrade_File_Latest ()
{
    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        MCU_NPU_FILE_PATH="McuAp_v0.6.bin"
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        CPLD_NPU_FILE_PATH="$MFG_WORK_DIR/cpld_fw_upgrade/bdx_wbmc_npu_cpld-v08_0x4863_bgmode-20200730.vme"
        SPI_COREBOOT_FILE_PATH="$MFG_WORK_DIR/coreboot_fw_upgrade/coreboot_v4_11_BMC_20200313.rom"
    fi

    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        CPLD_FILE_PATH="$MFG_WORK_DIR/cpld_fw_upgrade/porsche_cpldb2ac_bgm_20190414.vme"
        MCU_FB_FILE_PATH="porsche_fanboard_24pin_v1_6.efm8"
        MCU_MB_FILE_PATH="Porsche_MainBoard_24pin_V4_8_SF_EN_Y.efm8"
    elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        CPLD_FILE_PATH="$MFG_WORK_DIR/cpld_fw_upgrade/bugatti2-v844.vme"
        MCU_FB_FILE_PATH="Bugatti2_FanBoard_24pin_V1_6.efm8"
        MCU_MB_FILE_PATH="Bugatti2_MainBoard_24pin_V2_0_SF_EN_Y.efm8"
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        CPLD_FILE_PATH="$MFG_WORK_DIR/cpld_fw_upgrade/jaguar_2t0_er_cpld_bac_bgm_20190429.vme"
        MCU_FB_FILE_PATH="Jaguar_FanBoard_24pin_V1_6.efm8"
        MCU_MB_FILE_PATH="Jaguar_MainBoard_24pin_V1_2.efm8"
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        CPLD_FILE_PATH="$MFG_WORK_DIR/cpld_fw_upgrade/gemini-b3a1c2-20200713.vme"
        MCU_FB_FILE_PATH="DataCenter_FanBoard_24pin_V0_4.efm8"
        MCU_MB_FILE_PATH="Gemini_MainBoard_24pin_V0_5_SF_EN_Y.efm8"
    fi

    CPLD_REFRESH_FILE_PATH="$MFG_WORK_DIR/cpld_fw_upgrade/mb-refresh_3cpld-20200729.vme"
}
function Upgrade_File_Old ()
{
    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        MCU_NPU_FILE_PATH="/mnt/fw_mcu_npu_old_version.bin"                 ### v9.9
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        CPLD_NPU_FILE_PATH="/mnt/fw_regression_test/bdx_de_wbmc_npu_cpld_bgm-0xA2C3_v08_test1-20200713.vme"       ## v8_test1
        SPI_COREBOOT_FILE_PATH="$MFG_WORK_DIR/coreboot_fw_upgrade/coreboot_v4_9_ONIE_medDebugMsg_gpioInit.rom"    ### v4.9 - 20191105
    fi

    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        CPLD_FILE_PATH="/mnt/fw_cpld_old_version.vme"                       ### B0A0C0_BGM_20190414
        MCU_FB_FILE_PATH="/mnt/porsche_fanboard_24pin_old_version.efm8"     ### v1.5
        MCU_MB_FILE_PATH="/mnt/porsche_mainboard_24pin_old_version.efm8"    ### v4.7
    elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        CPLD_FILE_PATH="/mnt/fw_cpld_old_version.vme"                       ### bugatti2_cab_000
        MCU_FB_FILE_PATH="/mnt/Bugatti2_FanBoard_24pin_old_version.efm8"    ### v1.4
        MCU_MB_FILE_PATH="/mnt/Bugatti2_MainBoard_24pin_old_version.efm8"   ### v1.6
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        CPLD_FILE_PATH="/mnt/fw_cpld_old_version.vme"                       ### Need EE provide !!! version not fix!!!
        MCU_FB_FILE_PATH="/mnt/Jaguar_FanBoard_24pin_old_version.efm8"      ### v1.4
        MCU_MB_FILE_PATH="/mnt/Jaguar_MainBoard_24pin_old_version.efm8"     ### v1.1
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        CPLD_FILE_PATH="/mnt/fw_regression_test/gemini-b2ac-20200324.vme"
        MCU_FB_FILE_PATH="/mnt/fw_regression_test/DataCenter_FanBoard_24pin_V9_9_FWUG_Test.efm8"          ### v9.9
        MCU_MB_FILE_PATH="/mnt/fw_regression_test/Gemini_MainBoard_24pin_V9_9_SF_EN_Y_FWUG_Test.efm8"     ### v9.9 , smart-fan enable.
    fi

    CPLD_REFRESH_FILE_PATH="$MFG_WORK_DIR/cpld_fw_upgrade/mb-refresh_3cpld-20200729.vme"
}


### part-A : make sure time information ###
function Check_Time ()
{
    time_sys=$( { date ; } 2>&1 )
    echo " # System time :"  $time_sys |& tee -a $log_file
    echo ''

    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        time_rtc=$( { ./dnv_rtc r ; } 2>&1 )
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        time_rtc=$( { hwclock ; } 2>&1 )
    fi
    echo " # RTC time    :" $time_rtc |& tee -a $log_file
    echo ''
}

function HW_Monitor ()
{
    sh $MFG_SOURCE_DIR/hw_monitor.sh |& tee -a $log_file
}

### part-D : downgrade/upgrade FW from USB
function Mount_USB ()
{
    usb_mount_target="/mnt"

    checkExist=$( mount | grep "$usb_mount_target" )
    if [[ -z $checkExist ]]; then
        usb_location=$( ls -al /dev/disk/by-id/ | grep "usb" | sed -e "/$EMMC_LABEL/d" | sed -n '$p' | cut -d '/' -f 3 )
        if [[ -z "$usb_location" ]];then
            echo " USB is not inserted." |& tee -a $log_file
        else
            mount /dev/$usb_location $usb_mount_target
            echo " USB mounted at /dev/$usb_location"
        fi
    fi
}

function FW_Upgrade_CPLD_Check ()
{
    cpld_install_result=$( { cat $cpldCheck_filePath | grep "PASS!" ; } 2>&1 )
    if [[ -z "$cpld_install_result" ]]; then
        echo " # CPLD upgrade result : FAIL" |& tee -a $log_file
        cat $cpldCheck_filePath >> $log_file
        Test_Fail_Mark
    else
        echo " # CPLD upgrade result : PASS" |& tee -a $log_file
        rm $cpldCheck_filePath
    fi
}

function FW_Upgrade_CPLD_NPU ()    ## for BDX-DE
{
    echo "Start NPU CPLD upgrade ... please wait 2 minutes ..."
    date |& tee -a $log_file

    sh $MFG_SOURCE_DIR/cpld_upgrade.sh npu $CPLD_NPU_FILE_PATH |& tee $cpldCheck_filePath &
    sleep 120    ## 2 mins
    if [[ ! -s $cpldCheck_filePath ]]; then    ## check file content is empty or not (empty present CPLD upgrade not finish)
        echo " !!! CPLD upgrade is not finish excusion and over timing ... start polling status in additional 1 minutes ..."
        while (( $waittime < 6 ))
        do
            sleep 10
            waittime=$(( waittime + 1 ))
            if [[ ! -s $cpldCheck_filePath ]]; then
                echo " still not finish ..."
            else
                cpld_upgrade_done=1
                break
            fi
        done

        if (( $cpld_upgrade_done == 0 )); then
            echo " !!! CPLD upgrade is not finish excusion and over timing ... it might be hanging ..."
            echo "     will kill original process, and then re-upgrade CPLD FW again !!!"
            killall pega_cpld_upgrade
            rm $cpldCheck_filePath
            sh $MFG_SOURCE_DIR/cpld_upgrade.sh npu $CPLD_NPU_FILE_PATH |& tee $cpldCheck_filePath
            date |& tee -a $log_file
            FW_Upgrade_CPLD_Check
        else
            FW_Upgrade_CPLD_Check
        fi
    else
        date |& tee -a $log_file
        FW_Upgrade_CPLD_Check
    fi
    echo ''

    date |& tee -a $log_file

    ### then remember to upgrade refresh mode to reboot DUT immediately.
}

function FW_Upgrade_CPLD_Refresh ()
{
    sh $MFG_SOURCE_DIR/cpld_upgrade.sh mb $CPLD_REFRESH_FILE_PATH |& tee $cpldCheck_filePath &
    sleep 30

    FW_Upgrade_CPLD_Check
}

function FW_Upgrade_CPLD ()
{
    waittime=0
    cpld_upgrade_done=0

    date |& tee -a $log_file

    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        echo "Start CPLD upgrade ... please wait 4 minutes ..."
        sh $MFG_SOURCE_DIR/cpld_upgrade.sh mb $CPLD_FILE_PATH |& tee $cpldCheck_filePath &
        sleep 240    ## 4 mins
    elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        echo "Start CPLD upgrade ... please wait 2 minutes ..."
        sh $MFG_SOURCE_DIR/cpld_upgrade.sh mb $CPLD_FILE_PATH |& tee $cpldCheck_filePath &
        sleep 120    ## 2 mins
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        echo "Start CPLD upgrade ... please wait 6 minutes ..."
        sh $MFG_SOURCE_DIR/cpld_upgrade.sh mb $CPLD_FILE_PATH |& tee $cpldCheck_filePath &
        sleep 360    ## 6 mins
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        echo "Start CPLD upgrade ... please wait 2 minutes ..."
        sh $MFG_SOURCE_DIR/cpld_upgrade.sh mb $CPLD_FILE_PATH |& tee $cpldCheck_filePath &
        sleep 120    ## 2 mins
    fi

    if [[ ! -s $cpldCheck_filePath ]]; then    # check file content is empty or not (empty present CPLD upgrade not finish)
        echo " !!! CPLD upgrade is not finish excusion and over timing ... start polling status in additional 6 minutes ..."
        while (( $waittime < 12 ))
        do
            sleep 30
            waittime=$(( waittime + 1 ))
            if [[ ! -s $cpldCheck_filePath ]]; then
                echo " still not finish ..."
            else
                cpld_upgrade_done=1
                break
            fi
        done

        if (( $cpld_upgrade_done == 0 )); then
            echo " !!! CPLD upgrade is not finish excusion and over timing ... it might be hanging ..."
            echo "     will kill original process, and then re-upgrade CPLD FW again !!!"
            killall cpld_upgrade.sh
            rm $cpldCheck_filePath
            sh $MFG_SOURCE_DIR/cpld_upgrade.sh mb $CPLD_FILE_PATH |& tee $cpldCheck_filePath
            date |& tee -a $log_file
            FW_Upgrade_CPLD_Check
        else
            FW_Upgrade_CPLD_Refresh    # FW_Upgrade_CPLD_Check
        fi
    else
        date |& tee -a $log_file
        FW_Upgrade_CPLD_Check
    fi
    echo ''
}

function FW_Upgrade_MCU_FB ()
{
    method=$1

    date |& tee -a $log_file

    sh $MFG_SOURCE_DIR/mcu_fw_upgrade.sh fb $MCU_FB_FILE_PATH $method |& tee $mcuCheck_filePath
    echo ''
    mcu_fb_install_result=$( { cat $mcuCheck_filePath | grep "errors" ; } 2>&1 )
    if [[ "$mcu_fb_install_result" != *"[ 0 ]"* ]]; then
        echo " # FB MCU upgrade result : FAIL" |& tee -a $log_file
        cat $mcuCheck_filePath >> $log_file
        date |& tee -a $log_file
        Test_Fail_Mark
    else
        echo " # FB MCU upgrade result : PASS" |& tee -a $log_file
        rm $mcuCheck_filePath
    fi
    echo ''

    date |& tee -a $log_file
}

function FW_Upgrade_MCU_MB ()
{
    method=$1

    date |& tee -a $log_file

    sh $MFG_SOURCE_DIR/mcu_fw_upgrade.sh mb $MCU_MB_FILE_PATH $method |& tee $mcuCheck_filePath
    echo ''
    mcu_mb_install_result=$( { cat $mcuCheck_filePath | grep "errors" ; } 2>&1 )
    if [[ "$mcu_mb_install_result" != *"[ 0 ]"* ]]; then
        echo " # MB MCU upgrade result : FAIL" |& tee -a $log_file
        cat $mcuCheck_filePath >> $log_file
        date |& tee -a $log_file
        Test_Fail_Mark
    else
        echo " # MB MCU upgrade result : PASS" |& tee -a $log_file
        rm $mcuCheck_filePath
    fi
    echo ''

    date |& tee -a $log_file
}

function FW_Upgrade_MCU_NPU ()    ## for DENVERTON
{
    date |& tee -a $log_file

    sh $MFG_SOURCE_DIR/mcu_fw_upgrade.sh npu $MCU_NPU_FILE_PATH "test" |& tee $mcuCheck_filePath
    echo ''
    mcu_npu_install_result=$( { cat $mcuCheck_filePath | grep "Done" ; } 2>&1 )
    if [[ -z "$mcu_npu_install_result" ]]; then
        echo " # NPU MCU upgrade result : FAIL" |& tee -a $log_file
        cat $mcuCheck_filePath >> $log_file
        date |& tee -a $log_file
        Test_Fail_Mark
    else
        echo " # NPU MCU upgrade result : PASS" |& tee -a $log_file
        rm $mcuCheck_filePath
    fi
    echo ''

    date |& tee -a $log_file
}

function FW_Upgrade_Main ()
{
    if (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 1 )); then
        FW_Upgrade_MCU_FB "sw"
        sleep 1
        FW_Upgrade_MCU_MB "sw"
        sleep 1
        FW_Upgrade_CPLD
        sleep 1
        if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
            FW_Upgrade_MCU_NPU
        elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
            FW_Upgrade_CPLD_NPU
        fi
    elif (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 3 )); then
        FW_Upgrade_CPLD
        sleep 1
        if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
            FW_Upgrade_MCU_NPU
        elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
            FW_Upgrade_CPLD_NPU
        fi
        sleep 1
        FW_Upgrade_MCU_FB "hw"
        sleep 1
        FW_Upgrade_MCU_MB "hw"
    fi
    ### reboot to upgrade NOS
}

### part-B : FW version check - defined in another script : fw_version_check.sh ###
function Check_Version_Result ()
{
    version_checked_fail=$FALSE

    feedback_need_upgrade=$( { cat "/tmp/version.txt" ; } 2>&1 )  ## need do follow upgrade action depends on return value.
    if (( $feedback_need_upgrade != 0 )); then
        ## MB CPLD
        if (( ( $feedback_need_upgrade & 0x10 ) == 16 || ( $feedback_need_upgrade & 0x20 ) == 32 || ( $feedback_need_upgrade & 0x40 ) == 64 )); then
            if [[ "$fw_reset_request" == "$TRUE" ]]; then
                FW_Upgrade_CPLD
            else
                version_checked_fail=$TRUE
            fi
        fi
        ## FB MCU
        if (( ( $feedback_need_upgrade & 0x8 ) == 8 )); then
            if [[ "$fw_reset_request" == "$TRUE" ]]; then
                FW_Upgrade_MCU_FB "sw"
            else
                version_checked_fail=$TRUE
            fi
        fi
        ## MB MCU
        if (( ( $feedback_need_upgrade & 0x4 ) == 4 )); then
            if [[ "$fw_reset_request" == "$TRUE" ]]; then
                FW_Upgrade_MCU_MB "sw"
            else
                version_checked_fail=$TRUE
            fi
        fi
        ## NPU FW
        if (( ( $feedback_need_upgrade & 0x2 ) == 2 )); then
            if [[ "$fw_reset_request" == "$TRUE" ]]; then
                FW_Upgrade_MCU_NPU
            else
                version_checked_fail=$TRUE
            fi
        fi

        if (( ( $feedback_need_upgrade & 0x1 ) == 1 )); then
            if [[ "$fw_reset_request" == "$TRUE" ]]; then
                FW_Upgrade_CPLD_NPU
            else
                version_checked_fail=$TRUE
            fi
        fi
    fi

    rm "/tmp/version.txt"

    if [[ "$version_checked_fail" == "$TRUE" ]] || [[ -f "/tmp/fw_checked_fail" ]]; then
        echo " ## Exit Test Due to Version Checked Fail"
        rm "/tmp/fw_checked_fail"
        sync
        Test_Fail_Mark
    fi
}

### part-C : internal packets forwarding test
function Traffic_Test ()
{
    date |& tee -a $log_file

    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        ## from entering SDK, pkt fowarding, parsing result logs, it cost 53 seconds with 2000 pkts.
        sh $MFG_SOURCE_DIR/diag_nps_traffic_test.sh 1 1 2 1 25 100 2000 1
    elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        sh $MFG_SOURCE_DIR/diag_bcm_traffic_test.sh 4 1 1 15 25 100 off on    ## 4 for internal loopback ; 1 (parameter 3) for traffic 1 min.
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        sh $MFG_SOURCE_DIR/diag_bcm_traffic_test.sh mode=4                    ## others parameter remain default (same as Bugatti2's case.)
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        sh $MFG_SOURCE_DIR/gemini_burnin.sh seconds=60
    fi

    traffic_test_result=$( { cat $pktCheck_filePath | grep "PASS" ; } 2>&1 )
    if [[ -z "$traffic_test_result" ]]; then
        echo " # Packet Transmit : FAIL" >> $log_file
        Check_Time
        if [[ "$PROJECT_NAME" != "PORSCHE" ]]; then
            Test_Fail_Mark   ## except NPS loopback test API issue in SDK 2.3.6, others platform need stop the test.
        fi
    else
        echo " # Packet Transmit : PASS" >> $log_file
    fi
    echo ''

    date |& tee -a $log_file
}


### others function
function SYS_LED_Status_Update ()
{
    request=$1

    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_SYSTEM_LED
    led_ctrl_reg_val=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG ; } 2>&1 )
    ## Clear [7:5] bits of LED control register (System-Status LED Control Bits).
    sys_led_status=$(( $led_ctrl_reg_val & 0x1F ))
    ## then add request action
    sys_led_status=$(( $sys_led_status | $request ))
    ## Set LED status to CPLD LED control register.
    Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $sys_led_status

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi
}

function Reset_To_Default ()
{
    SYS_LED_Status_Update 0x00    ## system led green on

    echo 0 > $roundCheck_bkp_filePath
    echo 1 > $roundCheck_filePath

    Upgrade_File_Latest     ## define the latest files to be upgrade, if version older.
    bash ${MFG_SOURCE_DIR}/fw_version_check.sh "reset"
    Check_Version_Result

    if [[ -f $log_file ]]; then
        rm $log_file
    fi

    if [[ -f "/tmp/fw_checked_fail" ]]; then
        rm "/tmp/fw_checked_fail"
        sync
    fi
}

function Test_Fail_Mark ()
{
    SYS_LED_Status_Update 0x80    ## system led amber blink
    exit 1
}

function Go_To_Next_Round ()
{
    nextRound=$(( $roundCheck + 1 ))
    echo " [debug] next round should be $nextRound"
    echo $nextRound > $roundCheck_filePath

    sync

    sleep 1
    roundCheck_confirm=$({ cat $roundCheck_filePath ; } 2>&1 )
    if (( $roundCheck_confirm != $nextRound )); then
        echo " [debug] re-write roundCheck file again ..."
        echo $nextRound > $roundCheck_filePath
        sync
    fi

    echo " This round is done." |& tee -a $log_file
}

function Remote_SPI_Select ()  ## for DENVERTON
{
    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        CONTROL_CHIP_SEL_REG=$DNV_CONTROL_CHIP_SEL_REG
        CONTROL_CHIP_SEL_MAN=$DNV_CONTROL_CHIP_SEL_DEFAULT
        CONTROL_CHIP_SEL_BKP=$DNV_CONTROL_CHIP_SEL_GOLDEN
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        CONTROL_CHIP_SEL_REG=$BDX_CONTROL_CHIP_SEL_REG
        CONTROL_CHIP_SEL_MAN=$BDX_CONTROL_CHIP_SEL_DEFAULT
        CONTROL_CHIP_SEL_BKP=$BDX_CONTROL_CHIP_SEL_GOLDEN
    fi

    ## check which was used in this moment, and then get md5sum
    sel_ori=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $CONTROL_CHIP_SEL_REG ; } 2>&1 )
    if (( $sel_ori == $CONTROL_CHIP_SEL_MAN ));then
        current_spi="Default"
        invert=$CONTROL_CHIP_SEL_BKP
        invert_spi="backup"
    else
        current_spi="Golden"
        invert=$CONTROL_CHIP_SEL_MAN
        invert_spi="man"
    fi
    echo " # current SPI is $current_spi" |& tee -a $log_file

    if (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 2 )); then
        ## switch to the other SPI
        Mutex_Check_And_Create
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
        fi

        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $CONTROL_CHIP_SEL_REG $invert
        chipSel=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $CONTROL_CHIP_SEL_REG ; } 2>&1 )

        Mutex_Clean
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
        fi
        if (( $chipSel != $invert )); then
            echo " Swtich to $invert_spi SPI Fail ..." |& tee -a $log_file
            date |& tee -a $log_file
            Test_Fail_Mark
        else
            echo " Swtich to $invert_spi SPI Done" |& tee -a $log_file
            Go_To_Next_Round
            reboot
        fi
    else
        if [[ "$current_spi" != "$spiCheck" ]]; then
            echo " # CS-pin check : FAIL" |& tee -a $log_file
            date |& tee -a $log_file
            Test_Fail_Mark
        else
            echo " # CS-pin check : PASS" |& tee -a $log_file
        fi
    fi
}

function SPI_Detect_Test ()
{
    pretest_size=4096

    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    ## pin to golden first
    cs_golden=$(( $sel_ori & 0xfe ))
    Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG $cs_golden

    pre_read=$( { mtd_debug read /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size $RESERVED_AREA ; } 2>&1 )
    usleep $action_delay
    pre_erase=$( { mtd_debug erase /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size ; } 2>&1 )
    usleep $action_delay
    if [[ "$pre_erase" == *"Connection timed out"* ]]; then
        spi_not_exist=$TRUE
    else
        spi_not_exist=$FALSE
        pre_restore=$( { mtd_debug write /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size $RESERVED_AREA ; } 2>&1 )
        usleep $action_delay
    fi

    ## re-pin to orig SPI
    Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG $sel_ori

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi
}

function FW_Upgrade_SPI_Coreboot ()  ## for BDX
{
    date |& tee -a $log_file

    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    sel_ori=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG ; } 2>&1 )

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi

    if (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 2 )); then
        if (( ( $sel_ori & 0x1 ) != $BDX_CONTROL_CHIP_SEL_DEFAULT ));then
            echo " # CS-pin check : FAIL" |& tee -a $log_file
            date |& tee -a $log_file
            Test_Fail_Mark
        else
            ## if 2 SPI flash were put, erase default one to make it boot from golden next round, or update default SPI self with another FW version.
            SPI_Detect_Test
            if [[ "$spi_not_exist" == "$FALSE" ]]; then
                sh $MFG_WORK_DIR/coreboot_fw_upgrade/coreboot_upgrade.sh "erase" |& tee $spiCheck_filePath
            else
                sh $MFG_WORK_DIR/coreboot_fw_upgrade/coreboot_upgrade.sh "upgrade" $SPI_COREBOOT_FILE_PATH |& tee $spiCheck_filePath
            fi
        fi
    elif (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 4 )); then
        ## switch to default SPI first
        cs_default=$(( $sel_ori | 0x01 ))
        Mutex_Check_And_Create
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
        fi

        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG $cs_default

        Mutex_Clean
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
        fi
        ## then upgrade default SPI
        sh $MFG_WORK_DIR/coreboot_fw_upgrade/coreboot_upgrade.sh "upgrade" $SPI_COREBOOT_FILE_PATH |& tee $spiCheck_filePath
    fi

    echo ''
    spi_install_result=$( { cat $spiCheck_filePath | grep "Done" ; } 2>&1 )
    if [[ -z "$spi_install_result" ]]; then
        echo " # SPI upgrade result : FAIL" |& tee -a $log_file
        cat $spiCheck_filePath >> $log_file
        date |& tee -a $log_file
        Test_Fail_Mark
    else
        echo " # SPI upgrade result : PASS" |& tee -a $log_file
        rm $spiCheck_filePath
    fi
    echo ''

    date |& tee -a $log_file
    Go_To_Next_Round
    reboot
}

function Mutex_Check_And_Create()
{
    ## check whether mutex key create by others process, if exist, wait until this procedure can create then keep go test.
    while [ -f $I2C_MUTEX_NODE ]
    do
        #echo " !!! Wait for I2C bus free !!!"
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

###  main start :

echo " # current project is $PROJECT_NAME"

if [[ ! -z "$1" ]] && [[ "$1" == "reset" ]]; then
    fw_reset_request=$TRUE
    Reset_To_Default
    echo "Setting were reset to default."
    exit 1
elif [[ ! -f $roundCheck_filePath ]]; then
    echo 1 > $roundCheck_filePath
    echo 0 > $roundCheck_bkp_filePath
    roundCheck=1
else
    roundCheck=$({ cat $roundCheck_filePath ; } 2>&1 )
    echo " [debug] original readout roundCheck = $roundCheck"
    if [[ ! -z $roundCheck ]]; then
        if [ -n "$(echo "$roundCheck" | sed -n "/^[0-9]\+$/p")" ]; then    ## check whether is numeric
            cp $roundCheck_filePath $roundCheck_bkp_filePath               ## backup for next bootup check
            sync
            sleep 1
            roundCheck_bkp=$({ cat $roundCheck_bkp_filePath ; } 2>&1 )
            echo " [debug] sync roundCheck_bkp number to $roundCheck_bkp"
        else
            echo "Oops ... roundCheck is not a number ... resume to normal value ..."
            roundCheck_bkp=$({ cat $roundCheck_bkp_filePath ; } 2>&1 )
            sleep 1
            roundCheck=$(( $roundCheck_bkp + 1 ))
        fi
    else
        echo " Weird ! roundCheck become EMPTY @@ Resume to normal value ..."
        roundCheck_bkp=$({ cat $roundCheck_bkp_filePath ; } 2>&1 )
        sleep 1
        roundCheck=$(( $roundCheck_bkp + 1 ))
    fi
fi
sleep 1

echo " [debug] after check (current) : roundCheck = $roundCheck"

if (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 1 || $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 0 )); then
    roundCheck_str="Latest Image  ( $roundCheck )"
elif (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 3 )); then
    roundCheck_str="Older Image  ( $roundCheck )"
else
    roundCheck_str="Transfer SPI  ( $roundCheck )"
fi

echo ''
echo " ============ [ $roundCheck_str ] =============" |& tee -a $log_file
echo ''

SYS_LED_Status_Update 0x20    ## test start, so let system led amber on

Check_Time

HW_Monitor

echo ''
echo " =======" |& tee -a $log_file
echo ''

if (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 1 )); then
    bash ${MFG_SOURCE_DIR}/fw_version_check.sh "$roundCheck" "1" "latest"
    Upgrade_File_Old
elif (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 3 )); then
    bash ${MFG_SOURCE_DIR}/fw_version_check.sh "$roundCheck" "1" "old"
    Upgrade_File_Latest
elif (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 0 )); then
    bash ${MFG_SOURCE_DIR}/fw_version_check.sh "$roundCheck" "1" "latest"
else
    # add condition to detecte boot image (BIOS or Coreboot) to decide SPI md5sum checking do or not
    if [ -d "/sys/firmware/efi/efivars" ] ; then
        echo " # Due to use BIOS, skip SPI flash upgrading temporary..."
        Go_To_Next_Round
        reboot
    else
        if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
            Remote_SPI_Select
        elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
            FW_Upgrade_SPI_Coreboot
        fi
    fi
fi

Check_Version_Result

echo ''
echo " =======" |& tee -a $log_file
echo ''

Traffic_Test

echo ''
echo " =======" |& tee -a $log_file
echo ''

if (( $roundCheck % $TOTAL_BOOTUP_PERCYCLE == 0 )); then
    if (( $roundCheck == $TOTAL_TEST_ROUND )); then
        Check_Time
        exit 1
    else
        Go_To_Next_Round
        echo " ! PWR OFF !"  |& tee -a $log_file
        exit 1
    fi
else
    Mount_USB
    FW_Upgrade_Main
fi

echo ''
echo " =======" |& tee -a $log_file
echo ''

Go_To_Next_Round

## reboot DUT
Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
    echo " Will Reset NPU MCU in 5 sec..."
    sleep 5s
    i2cget -f -y $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x43
elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    sleep 5s
    echo " Need to do NPU CPLD upgrade flash mode to make CPLD reflash and then will cause DUT reboot immediately."
    sh $MFG_SOURCE_DIR/cpld_upgrade.sh npu $MFG_WORK_DIR/cpld_fw_upgrade/bdxde-refresh-r02.vme
fi

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
