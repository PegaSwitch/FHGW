#! /bin/bash
# This script is to monitor modules' temperature

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

## Module Temperature register
MODULE_TEMPERATURE_CONTROL=0x48
MODULE_TEMPERATURE_REG=0x0
MODULE_TEMPERATURE_MSB=0x16    # reg 22 = temprature MSB
MODULE_TEMPERATURE_LSB=0x17    # reg 23 = temprature LSB

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

function Twos_Complement()
{
    isNeg=0
    x=$((10#$1));
    if [ "$x" -gt 32768 ]; then
        x=65536-$x
        isNeg=1
    fi
    temp_new=$x
}

function Caculator_Temperature()
{
    temp_tmp=$(( ( $temp_msb << 8 ) | $temp_lsb ))
    Twos_Complement $temp_tmp
    temp_integer=$(( ( $temp_new & 0xff00 ) >> 8 ))
    temp_decimal=$(( ( $temp_new & 0xff ) ))
    temp_dec=$( echo "scale=3; $temp_decimal / 256 / 1" | bc )

    if (( $isNeg == 1 )); then
        temp_integer=$(( $temp_integer * -1 ))
        finalTemp=$( echo "scale=3;  $temp_integer - $temp_dec" | bc )
    else
        finalTemp=$( echo "scale=3;  $temp_integer + $temp_dec" | bc )
    fi
}

function Get_Temperature ()
{
    ## 20200921 Due to BMC v3 (IPMI) not support that device (registers), need force use i2cget commands to access.
    if [[ "$input_string" == "" || "$input_string" == "lbm" ]]; then
        temp=$( { i2cget -y $I2C_BUS $MODULE_TEMPERATURE_CONTROL $MODULE_TEMPERATURE_REG ; } 2>&1 )
        usleep $I2C_ACTION_DELAY
    else
        temp_msb=$( { i2cget -y $I2C_BUS $MODULE_EEPROM_ADDR $MODULE_TEMPERATURE_MSB ; } 2>&1 )
        usleep $I2C_ACTION_DELAY
        temp_lsb=$( { i2cget -y $I2C_BUS $MODULE_EEPROM_ADDR $MODULE_TEMPERATURE_LSB ; } 2>&1 )
        usleep $I2C_ACTION_DELAY
        Caculator_Temperature
        temp=$finalTemp
    fi
}

function SFP_Temperature_Get ()
{
    mux_channel=$1
    cpld_addr=$2
    zsrr_reg=$3
    ports_perRound=$4
    zsmcr_reg=$5
    zsmcr_data=$6
    port_start=$7

    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $mux_channel     # change MUX 's channel.

    for (( statusReg = $zsrr_reg , index = 0 ; statusReg < ( $zsrr_reg + ( $ports_perRound / 2 )) ; statusReg++ , index++ ))
    do
        ## check present pin status.
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $statusReg ; } 2>&1 )
        data=$data_result

        read_data_control=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg ; } 2>&1 )
        for (( portIndex = 0 ; portIndex < 2 ; portIndex++ ))
        do
            portNum=$(( port_start + ( 2 * $index ) + $portIndex ))

            ## Check modules present, then read its data.
            if (( (( $data & 0x1 ) == 0x0 && portIndex == 0 ) || (( $data & 0x10 ) == 0x0 && portIndex == 1 ) )); then    ## means module insert
                ## Eable it's EEPROM WP.
                write_data_control=$(( 0x00 | ( $zsmcr_data + (2 * $index + $portIndex ) ) ))
                Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $write_data_control    # switch SCL control bus to the QSFP

                ## get Modules' temperature
                Get_Temperature

                printf "\tPort %d temperature %.2f\n" $portNum $temp
            else    ## module not exist
                printf "\tPort %d is NOT Present.\n" $portNum
            fi
            usleep $I2C_ACTION_DELAY
        done
        Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $read_data_control     # resume SCL control bus to all disconnect.
    done
}

function QSFP_Temperature_Get ()
{
    mux_channel=$1
    cpld_addr=$2
    zsrr_reg=$3
    ports_perRound=$4
    zsmcr_reg=$5
    zsmcr_data=$6
    port_start=$7

    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $mux_channel     # change MUX 's channel.

    ## check present pin status.
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsrr_reg ; } 2>&1 )
    data=$data_result

    if [[ "$PROJECT_NAME" == "PORSCHE" ]] ; then
        Write_I2C_Device_Node $I2C_BUS $cpld_addr 0x17 0x00
    fi

    for (( index = 0 ; index < $ports_perRound ; index += 1 ))
    do
        portNum=$(( port_start + $index ))

        ## Check modules present, then read its data.
        if (( (($data >> $index) & 0x1 ) == 0x0)); then    ## means module insert
            ## Eable it's EEPROM WP.
            read_data_control=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg ; } 2>&1 )
            if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
                write_data_control=$(( 0x00 | ( $zsmcr_data + $index ) ))
            else
                write_data_control=$(( $zsmcr_data + $index ))
            fi
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $write_data_control    # switch SCL control bus to the QSFP

            ## get Modules' temperature
            Get_Temperature

            printf "\tPort %d temperature %.2f\n" $portNum $temp

            Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $read_data_control     # resume SCL control bus to all disconnect.
        else    ## module not exist
            printf "\tPort %d is NOT Present.\n" $portNum
        fi
        usleep $I2C_ACTION_DELAY
    done

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
    echo "  [MFG] Module Monitor help message:"
    echo "    Ex: ./mfg_sources/module_monitor.sh"
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

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

printf "\t{ Module Temperature }\n"

if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
    QSFP_Temperature_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR1_REG 8 $CPLD_B_MODULE_MCR_REG 0 1   # QSFP-1~7
    QSFP_Temperature_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 4 $CPLD_B_MODULE_MCR_REG 8 8   # QSFP-8~12
    QSFP_Temperature_Get $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 8 $CPLD_A_MODULE_MCR_REG 0 13   # QSFP-13~20
    QSFP_Temperature_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 8 $CPLD_C_MODULE_MCR_REG 0 21  # QSFP-21~28
    QSFP_Temperature_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG 4 $CPLD_C_MODULE_MCR_REG 8 29  # QSFP-29~32
elif [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
    SFP_Temperature_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR_REG 12 $CPLD_B_MODULE_MCR_REG 1 1    # SFP-1~12
    SFP_Temperature_Get $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 24 $CPLD_A_MODULE_MCR_REG 1 13   # SFP-13~36
    SFP_Temperature_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 12 $CPLD_C_MODULE_MCR_REG 1 37  # SFP-37~48
    QSFP_Temperature_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG $QSFP_PORTS_AMOUNT $CPLD_C_MODULE_MCR_REG 13 49   # QSFP-49~54
elif [[ "$PROJECT_NAME" == "JAGUAR" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    SFP_Temperature_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR1_REG 8 $CPLD_B_MODULE_MCR_REG 1 1    # SFP-1~8
    SFP_Temperature_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 4 $CPLD_B_MODULE_MCR_REG 9 9    # SFP-9~12
    SFP_Temperature_Get $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 28 $CPLD_A_MODULE_MCR_REG 1 13   # SFP-13~40
    SFP_Temperature_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 8 $CPLD_C_MODULE_MCR_REG 1 41   # SFP-41~48
    QSFP_Temperature_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG $QSFP_PORTS_AMOUNT $CPLD_C_MODULE_MCR_REG 9 49    # QSFP-49~56
elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
    echo " ### not support yet " #####
fi

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
