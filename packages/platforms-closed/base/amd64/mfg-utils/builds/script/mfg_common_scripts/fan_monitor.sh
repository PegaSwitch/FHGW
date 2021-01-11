#! /bin/bash
# This script is to monitor FAN detail information

## variables defined ::
source ${HOME}/mfg/mfg_sources/platform_detect.sh

# FanBoard Function Mask
FAN_DIRECTION_MASK=0x02
FAN_ALERT_FUNC_MASK=0x04
FAN_LED_AMBER_FUNC_MASK=0x08
FAN_LED_GREEN_FUNC_MASK=0x10
FAN_LED_AUTO_FUNC_MASK=0x20
FAN_STATUS_ENABLE_MASK=0x40
FAN_STATUS_PRESENT_MASK=0x80

# FanBoard Alert Mask
FAN_NOT_CONNECT=0x80
FAN_INNER_RPM_ZERO=0x40
FAN_INNER_RPM_UNDER=0x20
FAN_INNER_RPM_OVER=0x10
FAN_OUTER_RPM_ZERO=0x08
FAN_OUTER_RPM_UNDER=0x04
FAN_OUTER_RPM_OVER=0x02
FAN_WRONG_AIRFLOW=0x01

fan_index_stop=$(( FAN_AMOUNT -1 ))

function Help_Message()
{
    echo ""
    echo "  [MFG] Fan Monitor help message:"
    echo "    Ex: ./mfg_sources/fan_monitor.sh"
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

function Read_I2C_Device_Node_Word()      ## read as word.
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register w
        sleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_TWO ; } 2>&1 )
        #echo $value_get_through_ipmi    # for debug, value format is " XX XX"
        sleep $I2C_ACTION_DELAY
        firstByte=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 5 3)))" ; } 2>&1 )
        secondByte=$( { printf '%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 3)))" ; } 2>&1 )
        appendBothByte=$( echo $firstByte$secondByte )
        echo $appendBothByte
        return
    fi
}

#
# Main
#
Input_Help $1

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

# Print Fan PWM
fan_pwm=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_FAN_PWM_REG ; } 2>&1 )
if [[ $fan_pwm != "" ]]; then
    printf "\tFan PWM:\t%d (percent)\n" "$fan_pwm"
fi

# ------------------------------------------------------------------------------------------------------------------------ #

# Print Fan PWM Mode
fan_pwm_mode=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_SMARTFAN_ENABLE_BASE_REG ; } 2>&1 )
if [[ $fan_pwm_mode != "" ]]; then
    if [ $(( fan_pwm_mode )) -eq 0 ]; then
        printf "\tSmartFan:\tDisable\n"
        #printf "\tPWM Mode:\tAuto\n"
    else
        printf "\tSmartFan:\tEnable\n"
        #printf "\tPWM Mode:\tManual\n"
    fi
fi
printf "\n"

# ------------------------------------------------------------------------------------------------------------------------ #

# Print Alert Mode
fan_alert_mode=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_FAN_ALERT_MODE_REG ; } 2>&1 )
if [[ $fan_alert_mode != "" ]]; then
    if [ $(( fan_alert_mode )) -eq 0 ]; then
        printf "\tAlertMode:\tRead On Clear\n"
        #printf "\tAlert Mode:\tKeep\n"
    else
        printf "\tAlertMode:\tAuto Clear\n"
        #printf "\tAlert Mode:\tAuto\n"
    fi
fi
printf "\n"

# ------------------------------------------------------------------------------------------------------------------------ #

printf "\t{ [Fan 1] - [Fan %d] R.P.M }\n" $FAN_AMOUNT
# Print Fan Inner R.P.M
for fan in $( seq 0 $fan_index_stop ) 
do
    fan_func_sel=$(( $MB_MCU_FAN_INNER_RPM_BASE_REG | $fan ))
    fan_inner_rpm=$( { Read_I2C_Device_Node_Word $I2C_BUS_MCU $MB_MCU_ADDR $fan_func_sel ; } 2>&1 )
    if [[ $fan_inner_rpm != "" ]]; then
        printf "\t[Fan %d] Inner R.P.M:\t%d rpm\n" $(( $fan + 1 )) $fan_inner_rpm
    fi
done
printf "\n"

# ------------------------------------------------------------------------------------------------------------------------ #

# Print Fan Outer R.P.M
for fan in $( seq 0 $fan_index_stop )
do
    fan_func_sel=$(( $MB_MCU_FAN_OUTER_RPM_BASE_REG | $fan ))
    fan_outer_rpm=$( { Read_I2C_Device_Node_Word $I2C_BUS_MCU $MB_MCU_ADDR $fan_func_sel ; } 2>&1 )
    if [[ $fan_outer_rpm != "" ]]; then
        printf "\t[Fan %d] Outer R.P.M:\t%d rpm\n" $(( $fan + 1 )) $fan_outer_rpm
    fi
done
printf "\n"

# ------------------------------------------------------------------------------------------------------------------------ #

# Print Fan Status
printf "\t{ [Fan 1] - [Fan %d] Status }\n" $FAN_AMOUNT

if [[ "$PROJECT_NAME" == "ASTON" ]]; then
    printf "\t\t    [Present]   [Enable]   [LED Auto]   [LED Green]   [LED Red]     [Airflow]   [Fan Alert]"
else
    printf "\t\t    [Present]   [Enable]   [LED Auto]   [LED Green]   [LED Amber]   [Airflow]   [Fan Alert]"
fi

for fan in $( seq 0 $fan_index_stop )
do
    fan_func_sel=$(( $MB_MCU_FAN_STATUS_BASE_REG | $fan ))
    fan_status=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $fan_func_sel ; } 2>&1 )
    if [[ $fan_status != "" ]]; then
        printf "\n\t[Fan %d]     " $(( $fan + 1 ))

        if [ $(( $fan_status & $FAN_STATUS_PRESENT_MASK )) -eq 0 ]; then
            printf "Y  "
        else
            printf "N  "
        fi

        if [ $(( $fan_status & $FAN_STATUS_ENABLE_MASK )) -eq 0 ]; then
            printf "         N  "
        else
            printf "         Y  "
        fi

        if [ $(( $fan_status & $FAN_LED_AUTO_FUNC_MASK )) -eq 0 ]; then
            printf "        N  "
        else
            printf "        Y  "
        fi

        if [ $(( $fan_status & $FAN_LED_GREEN_FUNC_MASK )) -eq 0 ]; then
            printf "          Off "
        else
            printf "          On  "
        fi

        if [ $(( $fan_status & $FAN_LED_AMBER_FUNC_MASK )) -eq 0 ]; then
            printf "          Off "
        else
            printf "          On  "
        fi

        if [ $(( $fan_status & $FAN_DIRECTION_MASK )) -eq 0 ]; then
            printf "          BtF  "
        else
            printf "          FtB  "
        fi

        if [ $(( $fan_status & $FAN_ALERT_FUNC_MASK )) -eq 0 ]; then
            printf "       N  "
        else
            printf "       Y  "
        fi
    fi
done
printf "\n\n"

# ------------------------------------------------------------------------------------------------------------------------ #

# Print Fan Alert
printf "\t{ [Fan 1] - [Fan %d] Alert }\n" $FAN_AMOUNT
printf "\t\t    [Not Connect]  [In rpm Zero]  [In rpm Under]  [In rpm Over]  [Out rpm Zero]  [Out rpm Under]  [Out rpm Over]  [Wrong Airflow]"
for fan in $( seq 0 $fan_index_stop )
do
    if (( $fan_index_stop >= 5 )); then
        fan_func_sel=$MB_MCU_FAN_ALERT_CONT_REG
    else
        fan_func_sel=$(( $MB_MCU_FAN_ALERT_REG + $fan ))
    fi
    fan_alert=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $fan_func_sel ; } 2>&1 )
    if [[ $fan_alert != "" ]]; then
        printf "\n\t[Fan %d]     " $(( $fan + 1 ))

        if [ $(( $fan_alert & $FAN_NOT_CONNECT )) -eq 0 ]; then
            printf "N  "
        else
            printf "Y  "
        fi

        if [ $(( $fan_alert & $FAN_INNER_RPM_ZERO )) -eq 0 ]; then
            printf "            N  "
        else
            printf "            Y  "
        fi

        if [ $(( $fan_alert & $FAN_INNER_RPM_UNDER )) -eq 0 ]; then
            printf "            N  "
        else
            printf "            Y  "
        fi

        if [ $(( $fan_alert & $FAN_INNER_RPM_OVER )) -eq 0 ]; then
            printf "           N  "
        else
            printf "           Y  "
        fi

        if [ $(( $fan_alert & $FAN_OUTER_RPM_ZERO )) -eq 0 ]; then
            printf "              N  "
        else
            printf "              Y  "
        fi

        if [ $(( $fan_alert & $FAN_OUTER_RPM_UNDER )) -eq 0 ]; then
            printf "             N  "
        else
            printf "             Y  "
        fi

        if [ $(( $fan_alert & $FAN_OUTER_RPM_OVER )) -eq 0 ]; then
            printf "              N  "
        else
            printf "              Y  "
        fi

        if [ $(( $fan_alert & $FAN_WRONG_AIRFLOW )) -eq 0 ]; then
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
