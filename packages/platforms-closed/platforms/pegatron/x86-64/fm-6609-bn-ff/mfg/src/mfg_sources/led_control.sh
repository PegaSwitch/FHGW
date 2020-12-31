#! /bin/bash

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

#CPLD_MCR_VALUE_NORMAL=0x1d
MB_MCU_BUS_ALERT_REG=0x58
MB_MCU_BUS_ALERT_MASK=0x1

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

## Detect FB connected or not before doing fan board LED test.
function Detect_FB_Existence()
{
    # Switch I2C MUX to MainBoard MCU
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU

    # Add FanBoard I2C bus alert check before do fan test.
    i2c_bus_alert=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_BUS_ALERT_REG ; } 2>&1 )
    # If cannot detect FanBoard via I2C bus.
    if (( ( $i2c_bus_alert & $MB_MCU_BUS_ALERT_MASK ) == 0x1 )); then
        printf "\n [MFG] Cannot detect fan board via I2C bus !!!\n\n"
        fb_connect=0
    else
        fb_connect=1
    fi
}

function Set_OOB_LED()
{
    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then    # with Marvell 88e1512
       if [[ $1 == "off" || $1 == "amber" || $1 == "blue" ]]; then
            ethtool -s eth2 msglvl 0
        elif [[ $1 == "green" || $1 == "greenblue" ]]; then
            ethtool -s eth2 msglvl 1
        else # normal
            ethtool -s eth2 msglvl 2
        fi
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        if [[ "$PROJECT_NAME" == "GEMINI" ]] || [[ "$PROJECT_NAME" == "ASTON" ]]; then    ## with Marvell 88e1512
            mii-tool -c 0x16,0x3         # change to page 3
            usleep 300000
            # origin_val=$( { mii-tool -g 0x10 ; } 2>&1 )
            default_val=0x1000    # $(( $origin_val & 0xff00 ))
            if [[ $1 == "off" || $1 == "amber" || $1 == "blue" ]]; then
                write_val=$(( $default_val | 0x88 ))    # set OOB LED to off
            elif [[ $1 == "green" || $1 == "greenblue" ]]; then
                write_val=$(( $default_val | 0x99 ))
            else # normal
                write_val=$(( $default_val | 0x17 ))    # set OOB LED to normal
            fi
            mii-tool -c 0x10,$write_val
            usleep 300000
            mii-tool -c 0x16,0x0         # change to page 0
        else    ## with Broadcom 54616s
            if [[ $1 == "off" || $1 == "amber" || $1 == "blue" ]]; then
                mii-tool -c 0x10,0x08    # set OOB LED to off
            elif [[ $1 == "green" || $1 == "greenblue" ]]; then
                mii-tool -c 0x10,0x10
            else # normal
                mii-tool -c 0x10,0x08    # set OOB LED to off first
                mii-tool -c 0x10,0x00    # set OOB LED to normal
            fi
        fi
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

function Help_Message()
{
    echo ""
    echo "  [MFG] LED Control help message:"
    if [[ "$PROJECT_NAME" == "BUGATTI" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        echo "    Ex: ./mfg_sources/led_control.sh [normal/greenblue/amber/blue/off]"
    elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
        echo "    Ex: ./mfg_sources/led_control.sh [normal/green/red/blue/off]"
    else
        echo "    Ex: ./mfg_sources/led_control.sh [normal/green/amber/blue/off]"
    fi
    echo ""
}

function Input_Help()
{
    input_string=$1

    if [[ $input_string == "-h" ]] || [[ $input_string == "-help" ]] || [[ $input_string == "--h" ]] ||
       [[ $input_string == "--help" ]] || [[ $input_string == "?" ]]; then
        Help_Message
        exit 1
    fi
}

#
# Main
#
Input_Help $1

if (( $#  < 1 )); then
    echo "  Need at least 1 parameter!"
    Help_Message
    exit 1
fi

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

Set_OOB_LED $1

## Control system LEDs and front ports' LED.
##  front ports' LED are set through MCR registers.
Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_SYSTEM_LED
if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
    if [[ "$1" == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_NORMAL
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $CPLD_LEDCR1_VALUE_NORMAL
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR2_REG $CPLD_LEDCR2_VALUE_NORMAL
    elif [[ "$1" == "greenblue" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_GREEN    # [4:3]=Green&Blue on
    elif [[ "$1" == "amber" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_AMBER    # [4:3]=amber on
    elif [[ "$1" == "off" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_OFF      # [4:3]=all off
    elif [[ "$1" == "blue" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_NORMAL
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $CPLD_LEDCR1_VALUE_OFF
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR2_REG $CPLD_LEDCR2_VALUE_BLUE
    fi
elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
    if [[ "$1" == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_NORMAL
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $CPLD_LEDCR1_VALUE_NORMAL
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR2_REG $CPLD_LEDCR2_VALUE_NORMAL
    elif [[ "$1" == "green" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_GREEN
    elif [[ "$1" == "red" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_RED
    elif [[ "$1" == "off" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_OFF
    elif [[ "$1" == "blue" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_BLUE
    fi
else
    if [[ "$1" == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_NORMAL
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $CPLD_LEDCR1_VALUE_NORMAL
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR2_REG $CPLD_LEDCR2_VALUE_NORMAL
    elif [[ "$1" == "green" ]] || [[ "$1" == "greenblue" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_GREEN
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $CPLD_LEDCR1_VALUE_GREEN
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR2_REG $CPLD_LEDCR2_VALUE_GREEN
    elif [[ "$1" == "amber" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_AMBER
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $CPLD_LEDCR1_VALUE_AMBER
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR2_REG $CPLD_LEDCR2_VALUE_AMBER
    elif [[ "$1" == "off" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_OFF
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $CPLD_LEDCR1_VALUE_OFF
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR2_REG $CPLD_LEDCR2_VALUE_OFF
    elif [[ "$1" == "blue" ]]; then
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_MCR_REG $CPLD_MCR_VALUE_OFF
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $CPLD_LEDCR1_VALUE_OFF
        Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR2_REG $CPLD_LEDCR2_VALUE_BLUE
    fi
fi

if [[ "$2" == "nofan" ]]; then
    printf "[MFG Msg] Skip control FB LED \n"
else
    Detect_FB_Existence
fi

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi

if [[ -z "$fb_connect" ]]; then
    echo "skip" > /null
elif [[ "$fb_connect" == "0" ]]; then
    printf "[MFG Msg] Skip control FB LED because cannot detect fan board via I2C bus.\n"
else
    if [[ "$1" == "off" || "$1" == "blue" ]]; then
        bash $MFG_SOURCE_DIR/fan_control.sh status all green off
        usleep 200000
        bash $MFG_SOURCE_DIR/fan_control.sh status all amber off
    elif [[ "$1" == "green" || "$1" == "greenblue" ]]; then
        bash $MFG_SOURCE_DIR/fan_control.sh status all green on
    elif [[ "$1" == "amber" ]]; then
        bash $MFG_SOURCE_DIR/fan_control.sh status all amber on
    else # normal
        bash $MFG_SOURCE_DIR/fan_control.sh status all LED auto
    fi
fi

echo "  Set LED $1 Done."
