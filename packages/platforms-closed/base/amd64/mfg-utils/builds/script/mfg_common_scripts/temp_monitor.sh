#! /bin/bash
# This script is to monitor Temperature sensor detail information

## variables defined ::
source ${HOME}/mfg/mfg_sources/platform_detect.sh

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
    echo "  [MFG] Temperature Monitor help message:"
    echo "    Ex: ./mfg_sources/temp_monitor.sh"
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
    sleep $I2C_ACTION_DELAY
}
 
function Mutex_Clean()
{
    rm $I2C_MUTEX_NODE
    sync
    sleep $I2C_ACTION_DELAY
}

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
    sleep $I2C_ACTION_DELAY
}

function Read_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register
        sleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE ; } 2>&1 )
        sleep $I2C_ACTION_DELAY
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

# ------------------------------------------------------------------------------------------------------------------------ #

Input_Help $1

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

# Print Temperature
printf "\t{ Temperature }\n"

## Thermal sensor on NPU.
temp_npu=$( { Read_I2C_Device_Node $I2C_BUS_ARBITER_AND_AFTER $NPU_TEMPER_SENSOR_ADDR $TEMPER_SENSOR_REG ; } 2>&1 )
if [[ $temp_npu != "" ]]; then
    printf "\tLM75B[NPU (Addr:0x4A)]:\t%d degrees Celsius.\n" "$temp_npu"
fi

temp_pcb=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_TEMPER_SENSOR_PCB_REG ; } 2>&1 )
if [[ $temp_pcb != "" ]]; then
    printf "\tLM75B[PCB (Addr:0x48)]:\t%d degrees Celsius.\n" "$temp_pcb"
fi

temp_mac=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_TEMPER_SENSOR_MAC_REG ; } 2>&1 )
if [[ $temp_mac != "" ]]; then
    printf "\tLM75B[PCB (Addr:0x49)]:\t%d degrees Celsius.\n" "$temp_mac"
fi

temp_fb=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_TEMPER_SENSOR_FB_REG ; } 2>&1 )
if [[ $temp_fb != "" ]]; then
    printf "\tLM75B[FanBoard (Addr:0x4A)]:\t%d degrees Celsius.\n" "$temp_fb"
fi

printf "\n"

# ------------------------------------------------------------------------------------------------------------------------ #

printf "\n"
printf "\t{ CPU core Temperature }\n"
tmp_file="/tmp/sensors.txt"

if (( 0 )); then
    echo "YES
    YES
    YES
    YES
    no 
      " | sensors-detect
fi
sensors > $tmp_file

declare -a array
for (( i = 1 ; i <= 4 ; i++ ))
do
    orderRaw=$i"p"
    array[i]=$( { cat $tmp_file | grep "Core" | sed -n "$orderRaw" ; } 2>&1 )
    echo "       " ${array[i]}
done

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi

# ------------------------------------------------------------------------------------------------------------------------ #

## Print Dummy Module Temperature
# bash $MFG_SOURCE_DIR/module_monitor.sh
# printf "\n"
