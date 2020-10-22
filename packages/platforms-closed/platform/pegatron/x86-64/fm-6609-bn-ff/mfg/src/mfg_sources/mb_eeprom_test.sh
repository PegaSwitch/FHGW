#!/bin/bash
########################################################################################
# This script is to read/write 2K eeprom.
# $1 is location byte, $2 is wrote data.
# ex. ./mfg_sources/mb_eeprom_test.sh 0x10 0x22
#     0x10 0x22 will make byte 0x10 with data 0x22
# !!! PS. This script should be sync if S/N and MAC address script were changed design.
########################################################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

EEPROM_SIZE=256

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

function Open_EEPROM_Access ()
{
    ## change MUX B to channel of access WP bit.
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_MB_EEPROM_WP

    ## to disable eeprom write protection bit.
    orig_value=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_MCR2_CONTROL $CPLD_MCR2_REG ; } 2>&1 )
    bitInvert=$(( ~ CPLD_MCR2_EEPROM_WP_BIT ))
    new_value=$(( $orig_value & $bitInvert ))
    Write_I2C_Device_Node $I2C_BUS $CPLD_MCR2_CONTROL $CPLD_MCR2_REG $new_value

    ## change MUX A channel 2 to access EEPROM
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_MB_EEPROM $I2C_MUX_CHANNEL_MB_EEPROM

    ## make sure 0x54 show up.
    #i2cdetect -y $I2C_BUS
}

function Close_EEPROM_Access ()
{
    ## change MUX B to channel of access WP bit.
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_MB_EEPROM_WP
    Write_I2C_Device_Node $I2C_BUS $CPLD_MCR2_CONTROL $CPLD_MCR2_REG $orig_value
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

if (( $# < 2 )); then
    echo " Please enter address and data. Ex: ./mfg_sources/mb_eeprom_test.sh 0x10 0x22"
elif (( $1 > $EEPROM_SIZE )); then
    echo " Invalid address, parameter 1 need to smaller than $EEPROM_SIZE ."
else
    target_addr=$1
    target_value=$2

    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    Open_EEPROM_Access

    ## dump out EEPROM value
    #i2cdump -y $I2C_BUS $MB_EEPROM_ADDR b

    ## write data to pointed location bit.
    orig_data=$( { Read_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $target_addr ; } 2>&1 )
    Write_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $target_addr $target_value

    ## dump out EEPROM value for check ( in bye format)
    i2cdump -y $I2C_BUS $MB_EEPROM_ADDR b

    ## get back value to check data wrote.
    read_data=$( { Read_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $target_addr ; } 2>&1 )
    if (( $read_data == $target_value )); then
        echo " # EEPROM r/w test PASS"
    else
        echo " # EEPROM r/w test FAIL"
    fi

    ## restore origin data
    Write_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $target_addr $orig_data

    Close_EEPROM_Access

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi
fi
