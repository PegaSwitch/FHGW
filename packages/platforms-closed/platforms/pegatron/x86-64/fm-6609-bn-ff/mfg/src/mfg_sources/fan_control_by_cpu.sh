#! /bin/bash
## This script is to configure FAN detail information

## use global defined parameters.
source /home/root/mfg/mfg_sources/platform_detect.sh

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

function FAN_Data_Set()     # $1 = $request ; $2 = $data_input
{
    request=$1
    data_input=$2
    status_type=$3
    status_data=$4
    set_LED_manual=0

    if [ "$request" == "speed" ]; then
        fan_function_id=$BY_CPU_FB_MCU_PWM_WRITE_REG

        if (($data_input > 100) || ($data_input < 0)); then
            echo "  Invalid speed value, range is [0 % ~ 100 %]"
            exit 1
        fi
        Write_I2C_Device_Node $I2C_BUS $BY_CPU_FB_MCU_ADDR $fan_function_id $data_input
        return
    fi

    if [ "$request" == "status" ]; then

        # check fan index
        convertToASCII=$(printf "%d\n" "'$data_input")
        if (( $convertToASCII >= 65 && $convertToASCII <= 69 )); then
            inputIndex=$(($convertToASCII - 65))    # A(65):0 B(66):1 ... E(69):4
        elif (( $convertToASCII >=49 && $convertToASCII <= 53 )); then
            inputIndex=$(($convertToASCII - 49))    # 1(49):0 2(50):1 ... 5(53):4
        else
            echo "  Invalid fan index, please enter A ~ E, or 1 ~ $FAN_AMOUNT"
            exit 1
        fi

        # set function id
        if (( $inputIndex > $FAN_AMOUNT )); then
            echo "    Only $FAN_AMOUNT Fan, please enter A ~ E, or 1 ~ $FAN_AMOUNT"
            exit 1
        else
            fan_function_id=$(( $BY_CPU_FB_MCU_STATUS_WRITE_BASE_REG + ( $inputIndex * 4 ) ))
        fi

        # set status type & data
        if [ "$status_type" == "Fan" ] && [ "$status_data" == "enable" ]; then
            fan_status_type=$BY_CPU_FB_MCU_ENABLE_MASK
            fan_status_data=$BY_CPU_FB_MCU_ENABLE_MASK

        elif [ "$status_type" == "Fan" ] && [ "$status_data" == "disable" ]; then
            fan_status_type=$BY_CPU_FB_MCU_ENABLE_MASK
            fan_status_data=0

        elif [ "$status_type" == "LED" ] && [ "$status_data" == "auto" ]; then
            fan_status_type=$BY_CPU_FB_MCU_LED_AUTO_MASK
            fan_status_data=$BY_CPU_FB_MCU_LED_AUTO_MASK

        elif [ "$status_type" == "LED" ] && [ "$status_data" == "manual" ]; then
            fan_status_type=$BY_CPU_FB_MCU_LED_AUTO_MASK
            fan_status_data=0

        elif [ "$status_type" == "green" ] && [ "$status_data" == "on" ]; then
            fan_status_type=$BY_CPU_FB_MCU_LED_GREEN_MASK
            fan_status_data=$BY_CPU_FB_MCU_LED_GREEN_MASK
            set_LED_manual=1

        elif [ "$status_type" == "green" ] && [ "$status_data" == "off" ]; then
            fan_status_type=$BY_CPU_FB_MCU_LED_GREEN_MASK
            fan_status_data=0
            set_LED_manual=1

        elif [ "$status_type" == "amber" ] && [ "$status_data" == "on" ]; then
            fan_status_type=$BY_CPU_FB_MCU_LED_AMBER_MASK
            fan_status_data=$BY_CPU_FB_MCU_LED_AMBER_MASK
            set_LED_manual=1

        elif [ "$status_type" == "amber" ] && [ "$status_data" == "off" ]; then
            fan_status_type=$BY_CPU_FB_MCU_LED_AMBER_MASK
            fan_status_data=0
            set_LED_manual=1

        else
            echo "  Invalid command."
            Help_Message
            exit 1
        fi

        if (( "set_LED_manual" == "1" )); then
            i2cset -y $I2C_BUS $BY_CPU_FB_MCU_ADDR $fan_function_id $BY_CPU_FB_MCU_LED_AUTO_MASK 0 i
        fi

        i2cset -y $I2C_BUS $BY_CPU_FB_MCU_ADDR $fan_function_id $fan_status_type $fan_status_data i
        return
    fi

    echo "  Invalid command."
    Help_Message
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

function Input_Help()
{
    input_string=$1

    if [[ $input_string == "-h" ]] || [[ $input_string == "-help" ]] || [[ $input_string == "--h" ]] ||
       [[ $input_string == "--help" ]] || [[ $input_string == "?" ]]; then
        Help_Message
        exit 1
    fi
}

function Help_Message()
{
    echo ""
    echo "  [MFG] Fan / LED Control help message:"
    echo "    fan-amount [5/6]"
    echo "    speed [0~100]"
    echo "    status [A~E/1~$FAN_AMOUNT/all] [Fan enable/Fan disable/LED auto/LED manual/green on/green off/amber on/amber off]"
    echo ""
    echo "      Ex: ./mfg_sources/fan_control_by_cpu.sh 5 speed 80"
    echo "      Ex: ./mfg_sources/fan_control_by_cpu.sh 5 status A Fan diasble"
    echo "      Ex: ./mfg_sources/fan_control_by_cpu.sh 5 status E LED manual"
    echo "      Ex: ./mfg_sources/fan_control_by_cpu.sh 5 status 3 green off"
    echo "      Ex: ./mfg_sources/fan_control_by_cpu.sh 5 status all amber on"
    echo ""
}

#
# Main
#
Input_Help $1

if (( $#  < 2 )); then
    echo "  Need at least 2 parameters!"
    Help_Message
    exit 1
fi

## Write FAN board ID information to specific register
if (( $1 == 5 )); then
    write_value=0x0
elif (( $1 == 6 )); then
    write_value=0x3
else
    echo " Invalid fan amount !"
    exit 1
fi

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

Write_I2C_Device_Node $I2C_BUS $BY_CPU_FB_MCU_ADDR 0xa5 $write_value

## Set fan data
if [ "$3"  == "all" ]; then
    for (( fanIndex = 1 ; fanIndex <= $FAN_AMOUNT ; fanIndex += 1 ))
    do
        FAN_Data_Set $2 $fanIndex $4 $5
    done
else
    FAN_Data_Set $2 $3 $4 $5
fi

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi

## Show message
if [ "$2" == "speed" ]; then
    printf "  Set Fan PWM to speed $3 %% Done.\n"

elif [ "$2" == "status" ] && [ "$4" == "Fan" ]; then
    printf "  Set Fan $3 $5 Done.\n"

elif [ "$2" == "status" ]; then
    printf "  Set Led $3 to $4 $5 mode Done.\n"

else
    echo "  Invalid command."
    Help_Message
fi
