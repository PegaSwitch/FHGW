#! /bin/bash
## This script is to monitor FAN detail information

## use global defined parameters.
source /home/root/mfg/mfg_sources/platform_detect.sh

i2c_result=0

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
    echo "  [MFG] Fan Monitor help message:"
    echo "    Ex: ./mfg_sources/fan_monitor_by_cpu.sh"
    echo ""
}

#
# Main
#
Input_Help $1

fan_amount=$1
if (( $FAN_AMOUNT == 0)); then
    fan_index_stop=$(( fan_amount -1 ))
else
    fan_index_stop=$(( FAN_AMOUNT -1 ))
fi

## Write FAN board ID information to specific register
if (( $fan_amount == 5 )); then
    write_value=0x0
elif (( $fan_amount == 6 )); then
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


# ------------------------------------------------------------------------------------------------------------------------ #

# Print Fan PWM
fan_pwm=$( { Read_I2C_Device_Node $CPU_I2C_BUS $BY_CPU_FB_MCU_ADDR $BY_CPU_FB_MCU_PWM_READ_REG ; } 2>&1 )
if [[ $fan_pwm != "" ]]; then
    printf "\n\tFan PWM:\t%d (percent)\n\n" "$fan_pwm"
fi

# ------------------------------------------------------------------------------------------------------------------------ #

printf "\t{ [Fan 1] - [Fan %d] R.P.M }\n" $fan_amount
# Print Fan Inner R.P.M
for fan in $( seq 0 $fan_index_stop )
do
    fan_func_sel=$(( $BY_CPU_FB_MCU_INNER_RPM_BASE_REG + ( $fan * 4 ) ))
    i2c_result=$( { Read_I2C_Device_Node_Word $CPU_I2C_BUS $BY_CPU_FB_MCU_ADDR $fan_func_sel ; } 2>&1 )
    usleep $I2C_ACTION_DELAY
    fan_inner_rpm=$(( (( $i2c_result & 0xff00 ) >> 8 ) + (( $i2c_result & 0x00ff ) << 8 ) ))
    if [[ $fan_inner_rpm != "" ]]; then
        printf "\t[Fan %d] Inner R.P.M:\t%d rpm\n" $(( $fan + 1 )) $fan_inner_rpm
    fi
done
printf "\n"

# ------------------------------------------------------------------------------------------------------------------------ #

# Print Fan Outer R.P.M
for fan in $( seq 0 $fan_index_stop )
do
    fan_func_sel=$(( $BY_CPU_FB_MCU_OUTER_RPM_BASE_REG + ( $fan * 4 ) ))
    i2c_result=$( { Read_I2C_Device_Node_Word $CPU_I2C_BUS $BY_CPU_FB_MCU_ADDR $fan_func_sel ; } 2>&1 )
    usleep $I2C_ACTION_DELAY
    fan_outer_rpm=$(( (( $i2c_result & 0xff00 ) >> 8 ) + (( $i2c_result & 0x00ff ) << 8 ) ))
    if [[ $fan_outer_rpm != "" ]]; then
        printf "\t[Fan %d] Outer R.P.M:\t%d rpm\n" $(( $fan + 1 )) $fan_outer_rpm
    fi
done
printf "\n"

# ------------------------------------------------------------------------------------------------------------------------ #

# Print Fan Status
printf "\t{ [Fan 1] - [Fan %d] Status }\n" $fan_amount
printf "\t\t    [Present]   [Enable]   [LED Auto]   [LED Green]   [LED Amber]   [Airflow]   [Fan Alert]"
for fan in $( seq 0 $fan_index_stop )
do
    fan_func_sel=$(( $BY_CPU_FB_MCU_STATUS_READ_BASE_REG + ( $fan * 4 ) ))
    fan_status=$( { Read_I2C_Device_Node_Word $CPU_I2C_BUS $BY_CPU_FB_MCU_ADDR $fan_func_sel ; } 2>&1 )
    usleep $I2C_ACTION_DELAY
    if [[ $fan_status != "" ]]; then
        printf "\n\t[Fan %d]     " $(( $fan + 1 ))

        if [ $(( $fan_status & $FB_MCU_NOT_CONNECT_MASK )) -eq 0 ]; then
            printf "Y  "
        else
            printf "N  "
        fi

        if [ $(( $fan_status & $BY_CPU_FB_MCU_ENABLE_MASK )) -eq 0 ]; then
            printf "         N  "
        else
            printf "         Y  "
        fi

        if [ $(( $fan_status & $BY_CPU_FB_MCU_LED_AUTO_MASK )) -eq 0 ]; then
            printf "        N  "
        else
            printf "        Y  "
        fi

        if [ $(( $fan_status & $BY_CPU_FB_MCU_LED_GREEN_MASK )) -eq 0 ]; then
            printf "          Off "
        else
            printf "          On  "
        fi

        if [ $(( $fan_status & $BY_CPU_FB_MCU_LED_AMBER_MASK )) -eq 0 ]; then
            printf "          Off "
        else
            printf "          On  "
        fi

        if [ $(( $fan_status & $BY_CPU_FB_MCU_AIRFLOW_MASK )) -eq 0 ]; then
            printf "          BtF  "
        else
            printf "          FtB  "
        fi

        if [ $(( $fan_status & $BY_CPU_FB_MCU_ALERT_MASK )) -eq 0 ]; then
            printf "       N  "
        else
            printf "       Y  "
        fi
    fi
done
printf "\n\n"

# ------------------------------------------------------------------------------------------------------------------------ #

# Print Fan Alert
printf "\t{ [Fan 1] - [Fan %d] Alert }\n" $fan_amount
printf "\t\t    [Not Connect]  [In rpm Zero]  [In rpm Under]  [In rpm Over]  [Out rpm Zero]  [Out rpm Under]  [Out rpm Over]  [Wrong Airflow]"
for fan in $( seq 0 $fan_index_stop )
do
    fan_func_sel=$(( $BY_CPU_FB_MCU_STATUS_READ_BASE_REG + ( $fan * 4 ) ))
    Read_I2C_Device_Node_Word $CPU_I2C_BUS $BY_CPU_FB_MCU_ADDR $fan_func_sel
    usleep $I2C_ACTION_DELAY
    fan_alert=$(( $i2c_result >> 8 ))
    if [[ $fan_alert != "" ]]; then
        printf "\n\t[Fan %d]     " $(( $fan + 1 ))

        if [ $(( $fan_alert & $FB_MCU_PRESENT_ALERT_MASK )) -eq 0 ]; then
            printf "N  "
        else
            printf "Y  "
        fi

        if [ $(( $fan_alert & $FB_MCU_INNER_RPM_ZERO_MASK )) -eq 0 ]; then
            printf "            N  "
        else
            printf "            Y  "
        fi

        if [ $(( $fan_alert & $FB_MCU_INNER_RPM_UNDER_MASK )) -eq 0 ]; then
            printf "            N  "
        else
            printf "            Y  "
        fi

        if [ $(( $fan_alert & $FB_MCU_INNER_RPM_OVER_MASK )) -eq 0 ]; then
            printf "           N  "
        else
            printf "           Y  "
        fi

        if [ $(( $fan_alert & $FB_MCU_OUTER_RPM_ZERO_MASK )) -eq 0 ]; then
            printf "              N  "
        else
            printf "              Y  "
        fi

        if [ $(( $fan_alert & $FB_MCU_OUTER_RPM_UNDER_MASK )) -eq 0 ]; then
            printf "             N  "
        else
            printf "             Y  "
        fi

        if [ $(( $fan_alert & $FB_MCU_OUTER_RPM_OVER_MASK )) -eq 0 ]; then
            printf "              N  "
        else
            printf "              Y  "
        fi

        if [ $(( $fan_alert & $FB_MCU_WRONG_AIRFLOW_MASK )) -eq 0 ]; then
            printf "             N  "
        else
            printf "             Y  "
        fi
    fi
done
printf "\n"

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
