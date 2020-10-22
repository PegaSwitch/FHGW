#! /bin/bash
# This script is to configure LED/FAN detail information

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

action_delay=100000
MB_MCU_SMARTFAN_ENABLE=0x01     # auto mode
MB_MCU_SMARTFAN_DISABLE=0x00    # manual mode
MB_MCU_FAN_STATUS_BASE_REG=0x40
FB_MCU_FAN_STATUS_CONTROL_REG=0x20
FB_MCU_LED_MODE_CONTROL_REG=0x30
FB_MCU_LED_MODE_GREEN_REG=0x40
FB_MCU_LED_MODE_AMBER_REG=0x50

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

function Set_Fan_Data()     # $1 = $request ; $2 = $data_input
{
    request=$1
    data_input=$2
    status_type=$3
    status_choice=$4

    if [ "$request" == "speed" ]; then
        fan_function_id=$MB_MCU_FAN_PWM_REG

        if ((($data_input > 100) || ($data_input < 0))); then
            echo "  Invalid speed value, range is [0 % ~ 100 %]"
            Mutex_Clean
            exit 1
        else
            # switch to manual mode first. (disable smart fan function)
            Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_ENABLE_BASE_REG $MB_MCU_SMARTFAN_DISABLE
            data=$data_input
        fi

    elif [ "$request" == "smart-fan" ]; then
        fan_function_id=$MB_MCU_SMARTFAN_ENABLE_BASE_REG

        if [ "$data_input" == "enable" ]; then
            data=$MB_MCU_SMARTFAN_ENABLE
        elif [ "$data_input" == "disable" ]; then
            data=$MB_MCU_SMARTFAN_DISABLE
        else
            echo "  Invalid smart-fan parameter, please enter \"enable\" or \"disable\""
            Mutex_Clean
            exit 1
        fi

    elif [ "$request" == "status" ]; then
        # FAN, LED STATUS
        convert_to_ascii=$(printf "%d\n" "'$data_input")
        if (( $FAN_AMOUNT == 6 )); then
            if (( $convert_to_ascii >= 65 && $convert_to_ascii <= 70 )); then
                input_index=$(($convert_to_ascii - 65))    # A(65):0 B(66):1 ... F(70):5
            elif (( $convert_to_ascii >=49 && $convert_to_ascii <= 54 )); then
                input_index=$(($convert_to_ascii - 49))    # 1(49):0 2(50):1 ... 6(54):5
            else
                echo "  Invalid fan index, please enter A ~ F, or 1 ~ 6"
                Mutex_Clean
                exit 1
            fi

            if (( $input_index > $FAN_AMOUNT )); then
                echo "    Only 5 Fan, please enter A ~ F, or 1 ~ 6"
                Mutex_Clean
                exit 1
            else
                fan_function_id=$(($MB_MCU_FAN_STATUS_BASE_REG | $input_index))
            fi
        else
            if (( $convert_to_ascii >= 65 && $convert_to_ascii <= 69 )); then
                input_index=$(($convert_to_ascii - 65))    # A(65):0 B(66):1 ... E(69):4
            elif (( $convert_to_ascii >=49 && $convert_to_ascii <= 53 )); then
                input_index=$(($convert_to_ascii - 49))    # 1(49):0 2(50):1 ... 5(53):4
            else
                echo "  Invalid fan index, please enter A ~ E, or 1 ~ 5"
                Mutex_Clean
                exit 1
            fi

            if (( $input_index > $FAN_AMOUNT )); then
                echo "    Only 5 Fan, please enter A ~ E, or 1 ~ 5"
                Mutex_Clean
                exit 1
            else
                fan_function_id=$(($MB_MCU_FAN_STATUS_BASE_REG | $input_index))
            fi
        fi

        # Decide data value with type and choice
        if [ "$status_type" == "Fan" ]; then
            if [ "$status_choice" == "enable" ]; then
                data=$(($FB_MCU_FAN_STATUS_CONTROL_REG | 0x1))
            else  # Disable
                data=$(($FB_MCU_FAN_STATUS_CONTROL_REG | 0x0))
            fi

        elif [ "$status_type" == "LED" ]; then
            if [ "$status_choice" == "manual" ]; then
                data=$(($FB_MCU_LED_MODE_CONTROL_REG | 0x0))
            else  # auto
                data=$(($FB_MCU_LED_MODE_CONTROL_REG | 0x1))
            fi

        elif [ "$status_type" == "green" ]; then
            # set to Manual mode first.
            Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $fan_function_id $FB_MCU_LED_MODE_CONTROL_REG
            if [ "$status_choice" == "on" ]; then
                data=$(($FB_MCU_LED_MODE_GREEN_REG | 0x1))
            else  # off
                data=$(($FB_MCU_LED_MODE_GREEN_REG | 0x0))
            fi

        elif [ "$status_type" == "amber" ]; then
            # set to Manual mode first.
            Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $fan_function_id $FB_MCU_LED_MODE_CONTROL_REG
            if [ "$status_choice" == "on" ]; then
                data=$(($FB_MCU_LED_MODE_AMBER_REG | 0x1))
            else  # off
                data=$(($FB_MCU_LED_MODE_AMBER_REG | 0x0))
            fi
        else
            echo "  Invalid command."
            Mutex_Clean
            Help_Message
            exit 1
        fi
    else
        echo "  Invalid command."
        Mutex_Clean
        Help_Message
        exit 1
    fi

    usleep $action_delay
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $fan_function_id $data
}

function Check_Fan_Data ()
{
    func=$1
    request=$2
    selection=$3

    while (( $redo_times >= 0 ))
    do
        readcheck=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $fan_function_id ; } 2>&1  )
        if [ "$func" == "speed" ]; then
            if (( "$readcheck" == "$data" )); then
                break
            fi
        elif [ "$func" == "smart-fan" ]; then
            if (( "$readcheck" == "$data" )); then
                break
            fi
        elif [ "$func" == "status" ]; then
            if [ "$request" == "Fan" ]; then
                check_bit=$(( ( $readcheck & 0x40 ) >> 6 ))
                if [[ ( "$selection" == "enable" ) && ( "$check_bit" == "1" ) ]] || [[ ( "$selection" == "disable" ) && ( "$check_bit" == "0" ) ]]; then
                    break
                fi
            elif [ "$request" == "LED" ]; then
                check_bit=$(( ( $readcheck & 0x20 ) >> 5 ))
                if [[ ( "$selection" == "manual" ) && ( "$check_bit" == "0" ) ]] || [[ ( "$selection" == "auto" ) && ( "$check_bit" == "1" ) ]]; then
                    break
                fi
            elif [ "$request" == "green" ]; then
                check_bit=$(( ( $readcheck & 0x10 ) >> 4 ))
                if [[ ( "$selection" == "off" ) && ( "$check_bit" == "0" ) ]] || [[ ( "$selection" == "on" ) && ( "$check_bit" == "1" ) ]]; then
                    break
                fi
            elif [ "$request" == "amber" ]; then
                check_bit=$(( ( $readcheck & 0x08 ) >> 3 ))
                if [[ ( "$selection" == "off" ) && ( "$check_bit" == "0" ) ]] || [[ ( "$selection" == "on" ) && ( "$check_bit" == "1" ) ]]; then
                    break
                fi
            fi
        fi
        redo_times=$(( $redo_times + 1 ))
        #echo "[debug] (func: $func, request: $request, selection: $selection) -> $redo_times"
        Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $fan_function_id $data    ## retry setting
    done
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
    echo "    speed [0~100]                 Ex: ./mfg_sources/fan_control.sh speed 80"
    echo "    smart-fan [enable/disable]    Ex: ./mfg_sources/fan_control.sh smart-fan enable"
    echo "    status [A(1) ~ E(5) / all] [Fan en/disable, LED manual/auto, green off/on, amber off/on] "
    echo "      Ex: ./mfg_sources/fan_control.sh status C Fan enable"
    echo "      Ex: ./mfg_sources/fan_control.sh status all LED manual"
    echo "      Ex: ./mfg_sources/fan_control.sh status A green off"
    echo "      Ex: ./mfg_sources/fan_control.sh status 4 amber on"
    echo ""
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

#
# Main
#
Input_Help $1

if (( $#  < 2 )); then
    echo "  Need at least 2 parameters!"
    Help_Message
    exit 1
fi

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

# Set I2C MUX_A to MCU first.
Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU

# Set fan data then check to make sure action.
if [ "$2"  == "all" ]; then
    for (( fan_index = 1 ; fan_index <= $FAN_AMOUNT ; fan_index += 1 ))
    do
        Set_Fan_Data $1 $fan_index $3 $4
        usleep $action_delay
        redo_times=0
        Check_Fan_Data  $1 $3 $4
    done
else
    Set_Fan_Data $1 $2 $3 $4
    usleep $action_delay
    redo_times=0
    Check_Fan_Data  $1 $3 $4
fi

# Resume I2C MUX.
Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A 0x0

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi

# Show message
if [ "$1" == "speed" ]; then
    printf "  Set Fan PWM to speed $2 %% Done.\n"
elif [ "$1" == "smart-fan" ]; then
    printf "  Set Smart Fan $2 Done.\n"
elif [ "$1" == "status" -a "$3" == "Fan" ]; then
    printf "  Set Fan $2 $4 Done.\n"
else
    printf "  Set Led $2 to $3 $4 mode Done.\n"
fi
