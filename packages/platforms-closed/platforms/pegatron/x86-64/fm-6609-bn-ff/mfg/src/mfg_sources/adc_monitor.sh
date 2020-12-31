#! /bin/bash
# This script is to monitor ADC detail information

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

gemini_need_skip=$FALSE

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

function Read_I2C_Device_Node_Word()      ## read as word.
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register w
        usleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_TWO ; } 2>&1 )
        #echo $value_get_through_ipmi    # for debug, value format is " XX XX"
        usleep $I2C_ACTION_DELAY
        firstByte=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 5 3)))" ; } 2>&1 )
        secondByte=$( { printf '%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 3)))" ; } 2>&1 )
        appendBothByte=$( echo $firstByte$secondByte )
        echo $appendBothByte
        return
    fi
}

function Help_Message()
{
    echo ""
    echo "  [MFG] ADC Monitor help message:"
    echo "    Ex: ./mfg_sources/adc_monitor.sh"
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

function Gemini_MB_Special_Case()
{
    ## MB v1.00 need skip monitor a register, as HW issue, will modify on MB v2.00
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR $CPLD_VER_REG ; } 2>&1 )
    mb_hw_ver=$(($data_result >> 5 ))
    if (( $mb_hw_ver == 1 )); then
        gemini_need_skip=$TRUE
    fi
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG 0x0
}

#
# Main
#
Input_Help $1

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    Gemini_MB_Special_Case
fi

# Set I2C MUX_A to channel (MainBoard MCU) first.
Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU

# Print ADC
printf "\t{ ADC }\n"
for (( pin = 0 ; pin < $MB_MCU_ADC_MONITOR_AMOUNT ; pin += 1 ))
do
    if [[ "$pin" == "7" ]] && [[ "$gemini_need_skip" == "$TRUE" ]]; then
        continue
    fi

    adc_func_sel=$(( $MB_MCU_ADC_MONITOR_BASE_REG | $pin ))
    voltage=$( { Read_I2C_Device_Node_Word $I2C_BUS $MB_MCU_ADDR $adc_func_sel ; } 2>&1 )

    if [[ $voltage != "" ]]; then
        printf "\t[${ADC_MONITOR_LABEL[$pin]}]:\t%d mV\n" $voltage
    fi
done

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
