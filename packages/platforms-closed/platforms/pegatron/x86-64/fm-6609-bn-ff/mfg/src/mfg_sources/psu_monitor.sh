#! /bin/bash
# This script is to monitor PSU detail information

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

PSU_VIN_REG=0x88
PSU_VOUT_REG=0x20
PSU_IIN_REG=0x89
PSU_IOUT_REG=0x8C
PSU_PIN_REG=0x97
PSU_POUT_REG=0x96
PSU_TEMP_1_REG=0x8D
PSU_TEMP_2_REG=0x8E
PSU_TEMP_3_REG=0x8F
PSU_FAN_SPEED_REG=0x90
flag_detect=0

function I2C_Device_Detect ()
{
    i2c_device=$1

    ## Check Device Exist
    result=$( { i2cdetect -y $I2C_BUS ; } 2>&1 )
    usleep 1000
    ## Get last match sub-string of string(i2c_device) after specified character(x).
    i2c_device_num=${i2c_device##*x}
    #echo "[MFG Debug] i2c_device_num ---> $i2c_device_num"
    if [[ $result != *"$i2c_device_num"* ]]; then
        device_exist_check=$FAIL
    else
        device_exist_check=$SUCCESS
    fi
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
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_TWO ; } 2>&1 )\
        #echo $value_get_through_ipmi    # for debug, value format is " XX XX"
        usleep $I2C_ACTION_DELAY
        ## 20200921 Due to BMC v3 will return fail msg, so need to add case to handle
        if [[ "$value_get_through_ipmi" == *"Unspecified error"* ]]; then
            appendBothByte=0x0000
        else
            firstByte=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 5 3)))" ; } 2>&1 )
            secondByte=$( { printf '%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 3)))" ; } 2>&1 )
            appendBothByte=$( echo $firstByte$secondByte )
        fi
        echo $appendBothByte
        return
    fi
}

Twos_Expon() { x=$((10#$1)); [ "$x" -gt 15 ] && ((x=x-32)); exponVal=$x ; }             # 15=01111'b         ; 32=1000'b*2
Twos_Mantissa() { x=$((10#$1)); [ "$x" -gt 1023 ] && ((x=x-2048)); mantissaVal=$x ; }   # 1023=01111111111'b ; 2048=10000000000'b*2
function Caculator_Speed ()
{
    mantissa=$( { echo $(( $1 & 0x07ff )) ; } 2>&1 )
    Twos_Mantissa $mantissa
    expon=$( { echo $(( ( $1 & 0xf800 ) >> 11 )) ; } 2>&1 )
    Twos_Expon $expon
    if (( $exponVal < 0 )); then
        exponVal=$(( $exponVal * -1 ))
        finalResult=$(( $mantissaVal / ( 2 ** $exponVal ) | bc ))
    else
        finalResult=$(( $mantissaVal * ( 2 ** $exponVal ) | bc ))
    fi
}

function Get_PSU_Data ()    # $1 = $psu_addr ; $2 = $psu_reg
{
    psu_addr=$1
    psu_reg=$2

    data_result=$( { Read_I2C_Device_Node_Word $I2C_BUS $psu_addr $psu_reg ; } 2>&1 )
    # Check data_result not empty (PSU not inserted)
    if [[ $data_result == "" ]]; then
        printf "\tNo Power Input!!!\n"
        return
    fi

    data=$data_result                                      # This is to prevent inside caculation met error, so use addition parameter.
    if (( $psu_reg == PSU_VOUT_REG )); then
        val_1=$(($data & 0x001f))
        data=$( { Read_I2C_Device_Node_Word $I2C_BUS $psu_addr 0x8b ; } 2>&1 )
        val_2=$(($data & 0xffff))                      # If skip this action, 'val_2 * val_3' is hex * float, cause "parse error" !!!
    else
        val_1=$((($data & 0xf800) >> 11))
        val_2=$(($data & 0x07ff))
    fi

    if (($val_1 & 0x10)); then               # means the value is negative. Ex.0x1d=0001 1101. And it will cause float variable problem in bash
        val_1=$(((~$val_1 & 0x1f) + 0x1))    # do 2's complement

        # because shell script not accept power negative value neither float point variable, so use 'bc' function to get float.     
        val_3=$(echo "scale=5; 1/(2^$val_1)/1" | bc)
    else 
        val_3=$((2 ** $val_1))
    fi

    # Calculate the needed value and print out.
    if (( $psu_reg == PSU_VIN_REG )); then
        V_in=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD V_in:       %.3f\n' $V_in
    elif (( $psu_reg == PSU_VOUT_REG )); then
        V_out=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD V_out:      %.3f\n' $V_out
    elif (( $psu_reg == PSU_IIN_REG )); then
        I_in=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD I_in:       %.3f\n' $I_in
    elif (( $psu_reg == PSU_IOUT_REG )); then
        I_out=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD I_out:      %.3f\n' $I_out
    elif (( $psu_reg == PSU_PIN_REG )); then
        P_in=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD P_in:       %.3f\n' $P_in
    elif (( $psu_reg == PSU_POUT_REG )); then
        P_out=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD P_out:      %.3f\n' $P_out
        if [[ "$P_out" > "0" ]]; then
            flag_detect=1
        fi
    elif (( $psu_reg == PSU_TEMP_1_REG )); then
        Temp_1=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD Temp_1:     %.3f\n' $Temp_1
    elif (( $psu_reg == PSU_TEMP_2_REG )); then
        Temp_2=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD Temp_2:     %.3f\n' $Temp_2
    elif (( $psu_reg == PSU_TEMP_3_REG )); then
        Temp_3=$(echo "scale=5; $val_2 * $val_3 / 1" | bc)
        printf '\tREAD Temp_3:     %.3f\n' $Temp_3
    elif (( $psu_reg == PSU_FAN_SPEED_REG )); then
        Caculator_Speed $data_result
        Speed_fan=$finalResult
        printf '\tREAD Speed_fan:  %3.0f\n' $Speed_fan
    fi
}

function Help_Message()
{
    echo ""
    echo "  [MFG] PSU Monitor help message:"
    echo "    Ex: ./mfg_sources/psu_monitor.sh"
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

#
# Main
#
Input_Help $1

# ------------------------------------------------------------------------------------------------------------------------ #

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

# Set I2C MUX_A to channel 0 (PSU_A) first.
i2cset -y $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_A_CHANNEL_0

printf "\t{ PSU-A Information }\n"
I2C_Device_Detect $PSU_A_ADDR
if [[ "$device_exist_check" == "$FAIL" ]]; then
    printf "\t # PSU-A not exist , Skip detect data\n\n"
else
    # Print PSU Information
    Get_PSU_Data $PSU_A_ADDR $PSU_VIN_REG
    Get_PSU_Data $PSU_A_ADDR $PSU_VOUT_REG
    Get_PSU_Data $PSU_A_ADDR $PSU_IIN_REG
    Get_PSU_Data $PSU_A_ADDR $PSU_IOUT_REG
    Get_PSU_Data $PSU_A_ADDR $PSU_PIN_REG
    Get_PSU_Data $PSU_A_ADDR $PSU_POUT_REG
    Get_PSU_Data $PSU_A_ADDR $PSU_FAN_SPEED_REG
    if (( $flag_detect == 1 )); then
        Get_PSU_Data $PSU_A_ADDR $PSU_TEMP_1_REG
        Get_PSU_Data $PSU_A_ADDR $PSU_TEMP_2_REG
        Get_PSU_Data $PSU_A_ADDR $PSU_TEMP_3_REG
        flag_detect=0
    else
        printf "\tSkip detect Temperature data\n"
    fi
    printf "\n"
fi

# ------------------------------------------------------------------------------------------------------------------------ #

# Set I2C MUX_A to channel 1 (PSU_B) first.
i2cset -y $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_A_CHANNEL_1

printf "\t{ PSU-B Information }\n"
I2C_Device_Detect $PSU_B_ADDR
if [[ "$device_exist_check" == "$FAIL" ]]; then
    printf "\t # PSU-B not exist , Skip detect data\n\n"
else
    Get_PSU_Data $PSU_B_ADDR $PSU_VIN_REG
    Get_PSU_Data $PSU_B_ADDR $PSU_VOUT_REG
    Get_PSU_Data $PSU_B_ADDR $PSU_IIN_REG
    Get_PSU_Data $PSU_B_ADDR $PSU_IOUT_REG
    Get_PSU_Data $PSU_B_ADDR $PSU_PIN_REG
    Get_PSU_Data $PSU_B_ADDR $PSU_POUT_REG
    Get_PSU_Data $PSU_B_ADDR $PSU_FAN_SPEED_REG
    if (( $flag_detect == 1 )); then
        Get_PSU_Data $PSU_B_ADDR $PSU_TEMP_1_REG
        Get_PSU_Data $PSU_B_ADDR $PSU_TEMP_2_REG
        Get_PSU_Data $PSU_B_ADDR $PSU_TEMP_3_REG
        flag_detect=0
    else
        printf "\tSkip detect Temperature data\n"
    fi
    printf "\n"
fi

## Restore MUX channel to default
i2cset -y $I2C_BUS $I2C_MUX_A $I2C_MUX_REG 0x0

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
