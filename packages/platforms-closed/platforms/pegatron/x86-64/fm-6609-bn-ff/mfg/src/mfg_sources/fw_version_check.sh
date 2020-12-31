#!/bin/bash

###################################################################################################################################################################
#  Input parameters only has 4 type of parameter combination :
#    0 -- none of parameter, mean to only check FW version is newest or not;
#    1 -- if only 1 parameter and value is 'reset', called when fw_regression to reset all FW as newest;
#    2 -- EDVT diag called, with 2 parameter, 1st is power-cycle round, 2nd is test-round in that power cycle;
#    3 -- fw_regression test case, 1st param is power-cycle round, 2nd is test-round in that power cycle, 3rd param is compared FW version case 'latest'/'old';
#
# 'fw_need_upgrade' is a return value to fw_regresstion_test.sh , default value is 0x00;
#  [0]=BDX_CPLD ; [1]=DNV_MCU ; [2]=MB_MCU ; [3]=FB_MCU ; [4]=MB_CPLD_A ; [5]=MB_CPLD_B ; [6]=MB_CPLD_C ;
###################################################################################################################################################################

source /home/root/mfg/mfg_sources/platform_detect.sh

fw_reset_request=$FALSE
fw_need_upgrade=0x0

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

function Version_Check_Value ()
{
    fw_target=$1

    ## Common
    log_file="$LOG_DIAG_VERSION_CHECK"
    spimd5Check_filePath="$LOG_DIAG_VERSION_SPI"
    tmp_file_versionCheck="/tmp/version.txt"

    versionCheck_linux="4.14.66"

    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        versionCheck_pmbus_npu_63="df338d30"
        versionCheck_pmbus_npu_64="9c38acce"

        md5sum_spi_major="dae8b825e0e7e6001a4e1af950dccd5f"      ## 20200203 coreboot 4.9 with GPIO init & medium level debug msg.
        md5sum_spi_backup="7bad38a3b3225310dcfcf331f5644228"     ## 20190531 coreboot 4.8 with no dbg msg.  (factory version)

    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        versionCheck_pmbus_npu_63="841e4474"
        versionCheck_pmbus_npu_64="d50129b2"

        md5sum_spi_major="760dbcd65044c7bbeaaf68234e87cda3"      ## 20200710 BIOS v02
        md5sum_spi_backup="bfc3989487d87112d670ef867a3aa9dd"     ## 20191105 coreboot 4.9
        ## 20200313 coreboot 4.11  "a6d87cc94816cdf4ed6dd12a151777c2"
    fi

    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        versionCheck_sdk="2.0.6"
        versionCheck_pmbus_mb_60="189d4fd4"
    elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        versionCheck_sdk="6.5.13"
        versionCheck_pmbus_mb_60="f75a879a"
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        versionCheck_sdk="6.5.13"
        versionCheck_pmbus_mb_60="f45a9c9a"

        pktCheck_filePath="$LOG_PATH_HOME/pega_traffic_test_result.tmp"    ### Jaguar different with others.
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        versionCheck_sdk="4.2.2020.3"
        versionCheck_pmbus_mb_60="1b0ce447"
        versionCheck_pmbus_mb_5f="1c51b6ac"
    fi

    ## by Project
    if [[ "$fw_target" == "old" ]]; then
        if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
            versionCheck_fw="0.0.18"
            versionCheck_npu="9.9"
            versionCheck_mb_mcu="4.7"
            versionCheck_fb_mcu="1.5"
            spiCheck="Golden"
        elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
            versionCheck_fw="1.4.3"
            versionCheck_npu="FW ver: 2" ####
            versionCheck_mb_mcu="1.6"
            versionCheck_fb_mcu="1.4"
        elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
            versionCheck_fw="0.0.5"      ####
            versionCheck_npu="FW ver: 2" ####
            versionCheck_mb_mcu="1.1"
            versionCheck_fb_mcu="1.4"
        elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
            versionCheck_fw="0.1.2"
            versionCheck_npu="FW ver: 9_test" #0xA2C3_v08_test1-20200713
            versionCheck_mb_mcu="9.9"
            versionCheck_fb_mcu="9.9"
        fi
        versionCheck_mb_cpld_b="FW ver: 2"    # 0
        versionCheck_mb_cpld_a="FW ver: 1"    # 0
        versionCheck_mb_cpld_c="FW ver: 1"    # 0
    else
        if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
            versionCheck_fw="0.0.19"
            versionCheck_npu="0.6"
            versionCheck_mb_mcu="4.8"
            versionCheck_fb_mcu="1.6"
            versionCheck_mb_cpld_b="FW ver: 3"
            versionCheck_mb_cpld_a="FW ver: 1"
            versionCheck_mb_cpld_c="FW ver: 1"
            spiCheck="Default"
        elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
            versionCheck_fw="1.4.4"
            versionCheck_npu="FW ver: 2"
            versionCheck_mb_cpld_b="FW ver: 4"
            versionCheck_mb_cpld_a="FW ver: 8"
            versionCheck_mb_cpld_c="FW ver: 4"
            versionCheck_mb_mcu="2.0"
            versionCheck_fb_mcu="1.6"
        elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
            versionCheck_fw="0.0.5"
            versionCheck_npu="FW ver: 2"
            versionCheck_mb_cpld_b="FW ver: 2"
            versionCheck_mb_cpld_a="FW ver: 2"
            versionCheck_mb_cpld_c="FW ver: 1"
            versionCheck_mb_mcu="1.2"
            versionCheck_fb_mcu="1.6"
        elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
            versionCheck_fw="0.1.3"
            versionCheck_npu="FW ver: 13_test"
            versionCheck_mb_cpld_b="FW ver: 3_test"
            versionCheck_mb_cpld_a="FW ver: 1_test"
            versionCheck_mb_cpld_c="FW ver: 2_test"
            versionCheck_mb_mcu="0.6"
            versionCheck_fb_mcu="0.4"
        fi
    fi
}

function Check_Version ()
{
    flag_test_result="PASS"

    timestamp &>> $log_file

    sh $MFG_WORK_DIR/show_version >> $tmp_file_versionCheck
    usleep 500000
    cat $tmp_file_versionCheck &>> $log_file

    ## MFG version
    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        version_fw=$( { cat $tmp_file_versionCheck | grep "Porsche 2" ; } 2>&1 )
    elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        version_fw=$( { cat $tmp_file_versionCheck | grep "Bugatti2_BDXDE" ; } 2>&1 )
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        version_fw=$( { cat $tmp_file_versionCheck | grep "Jaguar" ; } 2>&1 )
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        version_fw=$( { cat $tmp_file_versionCheck | grep "Gemini" ; } 2>&1 )
    fi

    if [[ "$version_fw" != *"$versionCheck_fw"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! Please re-install MFG NOS to newest version !!!"
        else
            echo " # MFG firmware check : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # MFG firmware check : FAIL"
            fi
        fi
    fi

    ## Linux kernel version
    version_linux=$( { cat $tmp_file_versionCheck | grep "Linux" ; } 2>&1 )
    if [[ "$version_linux" != *"$versionCheck_linux"* ]];then
        echo " # Linux version check     : FAIL" &>> $log_file
        flag_test_result="FAIL"
        if [[ "$show_on_console" == "$TRUE" ]]; then
            echo " # Linux version check : FAIL"
        fi
    fi

    ## switch SDK version
    version_sdk=$( { cat $tmp_file_versionCheck | grep "SDK" ; } 2>&1 )
    if [[ "$version_sdk" != *"$versionCheck_sdk"* ]];then
        echo " # SDK version check       : FAIL" &>> $log_file
        flag_test_result="FAIL"
        if [[ "$show_on_console" == "$TRUE" ]]; then
            echo " # SDK version check : FAIL"
        fi
    fi

    ## NPU control chipset (BDX:CPLD ; DNV:MCU) FW version
    if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        version_npu=$( { cat $tmp_file_versionCheck | grep "(NPU)" ; } 2>&1 )
        if [[ "$version_npu" != *"$versionCheck_npu"* ]];then
            if [[ "$fw_reset_request" == "$TRUE" ]]; then
                echo " !!! CPLD NPU FW need to be update ... "
                fw_need_upgrade=$(( $fw_need_upgrade | 0x1 ))
            else
                echo " # NPU CPLD version check  : FAIL" &>> $log_file
                flag_test_result="FAIL"
                if [[ "$show_on_console" == "$TRUE" ]]; then
                    echo " # NPU CPLD version check : FAIL"
                fi
            fi
        fi
    elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        version_npu=$( { cat $tmp_file_versionCheck | grep "MCU - NPU" ; } 2>&1 )
        if [[ "$version_npu" != *"$versionCheck_npu"* ]];then
            if [[ "$fw_reset_request" == "$TRUE" ]]; then
                echo " !!! NPU MCU FW need to be upgrade ..."
                fw_need_upgrade=$(( $fw_need_upgrade | 0x2 ))
            else
                echo " # NPU MCU version check   : FAIL" &>> $log_file
                flag_test_result="FAIL"
                if [[ "$show_on_console" == "$TRUE" ]]; then
                    echo " # NPU MCU version check : FAIL"
                fi
            fi
        fi
    fi

    ## MB MCU version
    version_mb_mcu=$( { cat $tmp_file_versionCheck | grep "MCU - Main Board" ; } 2>&1 )
    if [[ "$version_mb_mcu" != *"$versionCheck_mb_mcu"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! MB MCU FW need to be upgrade ..."
            fw_need_upgrade=$(( $fw_need_upgrade | 0x4 ))
        else
            echo " # MB MCU version check    : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # MB MCU version check    : FAIL"
            fi
        fi
    fi

    ## FB MCU version
    version_fb_mcu=$( { cat $tmp_file_versionCheck | grep "MCU - Fan  Board" ; } 2>&1 )
    if [[ "$version_fb_mcu" != *"$versionCheck_fb_mcu"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! FB MCU FW need to be upgrade ..."
            fw_need_upgrade=$(( $fw_need_upgrade | 0x8 ))
        else
            echo " # FB MCU version check    : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # FB MCU version check    : FAIL"
            fi
        fi
    fi

    ## MB CPLD version
    version_mb_cpld_a=$( { cat $tmp_file_versionCheck | grep "CPLD A" ; } 2>&1 )
    if [[ "$version_mb_cpld_a" != *"$versionCheck_mb_cpld_a"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! CPLD A FW need to be upgrade ..."
            fw_need_upgrade=$(( $fw_need_upgrade | 0x10 ))
        else
            echo " # MB CPLD A version check : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # MB CPLD A version check : FAIL"
            fi
        fi
    fi

    version_mb_cpld_b=$( { cat $tmp_file_versionCheck | grep "CPLD B" ; } 2>&1 )
    if [[ "$version_mb_cpld_b" != *"$versionCheck_mb_cpld_b"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! CPLD B FW need to be upgrade ..."
            fw_need_upgrade=$(( $fw_need_upgrade | 0x20 ))
        else
            echo " # MB CPLD B version check : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # MB CPLD B version check : FAIL"
            fi
        fi
    fi

    version_mb_cpld_c=$( { cat $tmp_file_versionCheck | grep "CPLD C" ; } 2>&1 )
    if [[ "$version_mb_cpld_c" != *"$versionCheck_mb_cpld_c"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! CPLD C FW need to be upgrade ..."
            fw_need_upgrade=$(( $fw_need_upgrade | 0x40 ))
        else
            echo " # MB CPLD C version check : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # MB CPLD C version check : FAIL"
            fi
        fi
    fi

    ## Power IC FW version
    pmbus_checksum_npu_63=$( { cat $tmp_file_versionCheck | grep "PMBus FW checksum (NPU 0x63)" ; } 2>&1 )
    if [[ "$pmbus_checksum_npu_63" != *"$versionCheck_pmbus_npu_63"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! PMBus (NPU 0x63) FW need to be upgrade ..."
        else
            echo " # PMBus (NPU 0x63) checksum check       : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # PMBus (NPU 0x63) checksum check       : FAIL"
            fi
        fi
    fi

    pmbus_checksum_npu_64=$( { cat $tmp_file_versionCheck | grep "PMBus FW checksum (NPU 0x64)" ; } 2>&1 )
    if [[ "$pmbus_checksum_npu_64" != *"$versionCheck_pmbus_npu_64"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! PMBus (NPU 0x64) FW need to be upgrade ..."
        else
            echo " # PMBus (NPU 0x64) checksum check       : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # PMBus (NPU 0x64) checksum check       : FAIL"
            fi
        fi
    fi

    pmbus_checksum_mb_60=$( { cat $tmp_file_versionCheck | grep "PMBus FW checksum (MB  0x60)" ; } 2>&1 )
    if [[ "$pmbus_checksum_mb_60" != *"$versionCheck_pmbus_mb_60"* ]];then
        if [[ "$fw_reset_request" == "$TRUE" ]]; then
            echo " !!! PMBus (MB  0x60) FW need to be upgrade ..."
        else
            echo " # PMBus (MB  0x60) checksum check       : FAIL" &>> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # PMBus (MB  0x60) checksum check       : FAIL"
            fi
        fi
    fi

    if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        pmbus_checksum_mb_5f=$( { cat $tmp_file_versionCheck | grep "PMBus FW checksum (MB  0x5F)" ; } 2>&1 )
        if [[ "$pmbus_checksum_mb_5f" != *"$versionCheck_pmbus_mb_5f"* ]];then
            if [[ "$fw_reset_request" == "$TRUE" ]]; then
                echo " !!! PMBus (MB  0x5f) FW need to be upgrade ..."
            else
                echo " # PMBus (MB  0x5F) checksum check       : FAIL" &>> $log_file
                flag_test_result="FAIL"
                if [[ "$show_on_console" == "$TRUE" ]]; then
                    echo " # PMBus (MB  0x5F) checksum check       : FAIL"
                fi
            fi
        fi
    fi

    ## PCIe link speed
    pcie_speed=$( { cat $tmp_file_versionCheck | grep "LnkSta" ; } 2>&1 )
    if [[ "$pcie_speed" != *"Speed 8GT/s"* ]];then
        echo " # MAC PCIe speed check       : FAIL" &>> $log_file
        flag_test_result="FAIL"
        if [[ "$show_on_console" == "$TRUE" ]]; then
            echo " # MAC PCIe speed check       : FAIL"
        fi
    fi

    rm $tmp_file_versionCheck

    ## SPI flash image md5sum check , add condition to detecte boot image (BIOS or Coreboot) to decide do or not
    if [ ! -d "/sys/firmware/efi/efivars" ] ; then
        Mutex_Check_And_Create
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
        fi

        if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
            sel_ori=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $DNV_CONTROL_CHIP_SEL_REG ; } 2>&1 )
            check_cs_pin=$sel_ori
        elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
            sel_ori=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG ; } 2>&1 )
            check_cs_pin=$(( $sel_ori & 0x1 ))
        fi

        Mutex_Clean
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
        fi

        if (( $check_cs_pin == $BDX_CONTROL_CHIP_SEL_DEFAULT || $check_cs_pin == $DNV_CONTROL_CHIP_SEL_DEFAULT ));then
            spi_boot_from="Default"
            spi_another_is="Golden"
            spi_bootup=$md5sum_spi_major
            spi_another=$md5sum_spi_backup
        else  ## boot from Golden
            spi_boot_from="Golden"
            spi_another_is="Default"
            spi_bootup=$md5sum_spi_backup
            spi_another=$md5sum_spi_major
        fi

        md5_spi=$( { bash $MFG_SOURCE_DIR/SPI_md5sum_check.sh $spi_bootup $spi_another ; } 2>&1 )
        md5_spi_result=$( { cat $spimd5Check_filePath | grep "FAIL" ; } 2>&1 )
        if [[ ! -z "$md5_spi_result" ]];then
            cat $spimd5Check_filePath >> $log_file
            flag_test_result="FAIL"
            if [[ "$show_on_console" == "$TRUE" ]]; then
                echo " # SPI firmware md5 check : FAIL"
            fi
        fi
        rm $spimd5Check_filePath
    fi

    ## final result
    if [[ "$flag_test_result" == "FAIL" ]]; then
        echo " " &>> $log_file
        echo "   ====> Version check result : FAIL" &>> $log_file
        if [[ "$show_on_console" == "$TRUE" ]]; then
            echo "   ====> Version check result : FAIL"
        fi

        if [[ ! -f "/tmp/fw_checked_fail" ]]; then
            touch "/tmp/fw_checked_fail"
            sync
        fi
    elif [[ "$fw_reset_request" != "$TRUE" ]]; then
        echo " " &>> $log_file
        echo "   ====> Version check result : PASS" &>> $log_file
        if [[ "$show_on_console" == "$TRUE" ]]; then
            echo "   ====> Version check result : PASS"
        fi
    fi

    fw_need_upgrade_decimal=$( { printf "%d" $fw_need_upgrade ; } 2>&1 )
    # return $fw_need_upgrade_decimal   ## but return will cause string not printed on screen ...
    echo $fw_need_upgrade_decimal > $tmp_file_versionCheck
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

if [[ -f "/tmp/fw_checked_fail" ]]; then
    rm "/tmp/fw_checked_fail"
    sync
fi

if (( $# == 2 ));  then
    Version_Check_Value "latest"
    echo " ---- Power Cycle $1 , Test Round $2 ----" &>> $log_file
elif (( $# == 3 ));  then
    show_on_console=$TRUE
    Version_Check_Value $3
    echo " ---- Power Cycle $1 , Test Round $2 ----" &>> $log_file
else
    show_on_console=$TRUE
    Version_Check_Value "latest"
    if [[ ! -z "$1" ]] && [[ "$1" == "reset" ]]; then
        fw_reset_request=$TRUE
    fi
fi

Check_Version
