#!/bin/bash

###############################################################################################
# This is for dual SPI usage, to check backup SPI's FW (BIOS region) checksum is right or not.
# $1 is md5sum of coreboot code , $2 is optional another SPI's md5sum.
###############################################################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

BIOS_REGION_ADDR=0xe00000   ####
BIOS_REGION_LEN=0x200000
READOUT_SPI_MAN="/tmp/readData_manSpi"
READOUT_SPI_BKP="/tmp/readData_bkpSpi"
RESERVED_AREA="/tmp/reserveOrig"
logFile="$LOG_DIAG_VERSION_SPI"
action_delay=500000

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

## check SPI md5sum
function Boot_Image_MD5sum ()
{
    outdata=$1

    if [[ "$outdata" == *"man"* ]];then
        checked_spi="Default SPI"
    else
        checked_spi="Golden SPI"
    fi

    mtd_debug read /dev/mtd0 $BIOS_REGION_ADDR $BIOS_REGION_LEN $outdata
    sleep 1
    checksum_outdata=$( { md5sum $outdata ; } 2>&1 )
    checksum=$( { echo $checksum_outdata | cut -d ' ' -f 1 ; } 2>&1 )
    if [[ "$current_spi" == "bootup" && "$checksum" != "$request_value" ]] || [[ "$current_spi" == "change" && "$spi_not_exist" == "0" && "$checksum" != "$second_md5Val" ]]; then
        echo "  BIOS checksum [$checked_spi] =" $checksum |& tee -a $logFile
        if [[ "$current_spi" == "change" ]]; then
            echo "  Request match             =" $second_md5Val |& tee -a $logFile
        else
            echo "  Request match             =" $request_value |& tee -a $logFile
        fi
        echo " ==> $checked_spi Test FAIL" |& tee -a $logFile
    else
        echo " ==> $checked_spi Test PASS" |& tee -a $logFile
    fi
}

function Clear_Temporary_Data ()
{
    if [[ -f $READOUT_SPI_MAN ]]; then
        rm $READOUT_SPI_MAN
    fi

    if [[ -f $READOUT_SPI_BKP ]];then
        rm $READOUT_SPI_BKP
    fi
}

function Restore_Setting ()
{
    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $DNV_CONTROL_CHIP_SEL_REG $sel_ori
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG $sel_ori
    fi
    usleep $I2C_ACTION_DELAY

    Clear_Temporary_Data
}

function Skip_And_Exit ()
{
    echo "  ====> Skip test due to SPI not exist." | tee -a $logFile
    Restore_Setting
    exit 1
}

function Switching_SPI_Pass ()
{
    echo " Swtich to $invert_spi SPI ..."
    current_spi="change"
    SPI_Detect_Test
}

function Switching_SPI_Fail ()
{
    echo " Swtich to $invert_spi SPI Fail , skip check checksum of $invert_spi SPI ..."
    Clear_Temporary_Data    # clear tmp data
    Mutex_Clean
    exit 1
}

function SPI_Detect_Test ()
{
    pretest_size=4096

    pre_read=$( { mtd_debug read /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size $RESERVED_AREA ; } 2>&1 )
    usleep $action_delay
    pre_erase=$( { mtd_debug erase /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size ; } 2>&1 )
    usleep $action_delay
    if [[ "$pre_erase" == *"Connection timed out"* ]]; then
        spi_not_exist=$TRUE
        Skip_And_Exit
    else
        spi_not_exist=$FALSE
        pre_restore=$( { mtd_debug write /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size $RESERVED_AREA ; } 2>&1 )
        usleep $action_delay
    fi
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


if [[ -z "$1" ]]; then
    echo " # Please provide md5sum value to be compare"
    exit 1
else
    request_value=$1

    ## if enter 2nd SPI's md5sum to be checked.
    if [[ ! -z "$2" ]]; then
        second_md5Val=$2
    else
        second_md5Val=$1
    fi

    if [[ ! -d "$LOG_PATH_STORAGE" ]]; then
        mkdir "$LOG_PATH_STORAGE"
    fi

    if [[ -f "$logFile" ]]; then
        rm $logFile
    fi
fi

## check which was used in this moment, and then get its md5sum.
Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

current_spi="bootup"

if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
    sel_ori=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $DNV_CONTROL_CHIP_SEL_REG ; } 2>&1 )
    if (( $sel_ori == $DNV_CONTROL_CHIP_SEL_DEFAULT ));then
        flag_current="Default"
        invert=$DNV_CONTROL_CHIP_SEL_GOLDEN
    else
        flag_current="Golden"
        invert=$DNV_CONTROL_CHIP_SEL_DEFAULT

    fi
elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    sel_ori=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG ; } 2>&1 )
    if (( ( $sel_ori & 0x1 ) == $BDX_CONTROL_CHIP_SEL_DEFAULT ));then
        flag_current="Default"
        invert=$BDX_CONTROL_CHIP_SEL_GOLDEN
    else
        flag_current="Golden"
        invert=$BDX_CONTROL_CHIP_SEL_DEFAULT
    fi
fi

if [[ "$flag_current"=="Default" ]]; then
    Boot_Image_MD5sum $READOUT_SPI_MAN
    invert_spi="Golden"
else
    Boot_Image_MD5sum $READOUT_SPI_BKP
    invert_spi="Default"
fi

## switch to the other SPI
if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
    Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $DNV_CONTROL_CHIP_SEL_REG $invert
    usleep $action_delay
    chipSel=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $DNV_CONTROL_CHIP_SEL_REG ; } 2>&1 )
    if (( $chipSel != $invert )); then
        Switching_SPI_Fail
    else
        Switching_SPI_Pass
        if (( $invert == $DNV_CONTROL_CHIP_SEL_DEFAULT ));then
            Boot_Image_MD5sum $READOUT_SPI_MAN
        else
            Boot_Image_MD5sum $READOUT_SPI_BKP
        fi
        Restore_Setting
    fi

elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    # echo " # Skip another SPI check" | tee -a $logFile

    new_cs_pin=$(( ( $sel_ori & 0xfe ) | $invert ))
    Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG $new_cs_pin
    usleep $action_delay
    chipSel=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG ; } 2>&1 )
    check_cp_pin=$(( $chipSel & 0x1 ))
    check_cp_pin_hex=$( { echo "0x"${check_cp_pin} ; } 2>&1 )
    if (( $check_cp_pin_hex != $invert ));then
        Switching_SPI_Fail
    else
        Switching_SPI_Pass
        if (( $invert == $BDX_CONTROL_CHIP_SEL_DEFAULT ));then
            Boot_Image_MD5sum $READOUT_SPI_MAN
        else
            Boot_Image_MD5sum $READOUT_SPI_BKP
        fi
        Restore_Setting
    fi
fi

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
