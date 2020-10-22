#!/bin/bash

##########################################################
# This script is use for stop i2c test in the background.
##########################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

test_log="$LOG_PATH_I2C/i2c_bus_test.log"

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

function Mutex_Check_And_Create()
{
    echo " # Wait for I2C bus free first !!!"
    ## check whether mutex key create by others process, if exist, wait until this procedure can create then keep go test.
    while [ -f $I2C_MUTEX_NODE ]
    do
        #echo " !!! Wait for I2C bus free !!!"
        sleep 1
        if [ ! -f /tmp/i2c-bus-mutex ]; then
            break
        fi
    done
    ## create mutex key
    touch /tmp/i2c-bus-mutex
    sync
    usleep 100000
}

function Mutex_Clean()
{
    rm /tmp/i2c-bus-mutex
    sync
    usleep 100000
}

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

echo " # Will stop I2C test immediately..."
pid=$( { ps | grep "i2c_bus" | grep -v "grep" | awk '{print $1}' ; } 2>&1 )
if [[ ! -z $pid ]]; then
    kill -9 $pid
fi

if [[ -f "$testLog" ]]; then
    echo " " &>> $testLog
    timestamp |& tee -a $testLog
    printf " ==== I2C bus test Stop , by maually forced. ====\n" |& tee -a $testLog
fi


### System LED Resume
Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_SYSTEM_LED    # change MUX B's channel
sys_led=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG ; } 2>&1 )
write_data=$CPLD_LEDCR1_VALUE_NORMAL                                      # make system led normal
Write_I2C_Device_Node $I2C_BUS $i2c_cpld_address $PEGA_I2C_CPLD_SYSLED $write_data


### Fan LED Resume to auto mode
write_data=0x31
Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU
Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $FB_MCU_FAN_A $write_data


### QSFP SCL control bus to disconnect.
if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_1
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_B $CPLD_B_MODULE_MCR_REG 0x00
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_A $CPLD_A_MODULE_MCR_REG 0x00
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_2
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_C $CPLD_C_MODULE_MCR_REG 0x00
elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_1
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_B $CPLD_B_MODULE_MCR_REG 0x0F
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_A $CPLD_A_MODULE_MCR_REG 0x0F
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_2
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_C $CPLD_C_MODULE_MCR_REG 0x0F
elif [[ "$PROJECT_NAME" == "JAGUAR" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_1
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_B $CPLD_B_MODULE_MCR_REG 0x00
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_A $CPLD_A_MODULE_MCR_REG 0x00
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_2
    Write_I2C_Device_Node $I2C_BUS $PEGA_I2C_CPLD_C $CPLD_C_MODULE_MCR_REG 0x00
elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
    echo " ### not support yet " #####
fi

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
