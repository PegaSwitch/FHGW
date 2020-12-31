#! /bin/bash
# This script is to set module dummy load

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

MODULE_VOLTAGE_CONTROL=0x27
MODULE_GPO_REG=0x3
MODULE_LOAD_REG=0x1

dummy_load=0x0
dummy_load_watt=0x0
portNum=1

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

function Module_Dummy_Load_Set ()    ## 20200921 Due to BMC v3 (IPMI) not support that registers, need to force use i2c commands.
{
    ## set QSFP GPO
    i2cset -y $I2C_BUS $MODULE_VOLTAGE_CONTROL $MODULE_GPO_REG 0x0
    usleep $I2C_ACTION_DELAY

    ## set QSFP dummy load
    # EX: i2cset -y 0 0x27 0x1 $dummy_load
    i2cset -y $I2C_BUS $MODULE_VOLTAGE_CONTROL $MODULE_LOAD_REG $dummy_load
    usleep $I2C_ACTION_DELAY

    ## check QSFP dummy load
    watt=$( { i2cget -y $I2C_BUS $MODULE_VOLTAGE_CONTROL $MODULE_LOAD_REG ; } 2>&1 )
    usleep $I2C_ACTION_DELAY

    ## Check watt not empty
    if [[ $watt == "" ]]; then
        return
    fi

    printf "      Port %d power is set to 0x%x ($dummy_load_watt watt)\n" $portNum $watt
}

function SFP_Loading_Set ()
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

                ## Set Modules' Loading
                Module_Dummy_Load_Set

            else    ## module not exist
                printf "\tPort %d is NOT Present.\n" $portNum
            fi
            usleep $I2C_ACTION_DELAY
        done
        Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $read_data_control     # resume SCL control bus to all disconnect.
    done
}

function QSFP_Loading_Set ()
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

            ## Set Modules' Loading
            Module_Dummy_Load_Set

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

function Input_Check()
{
    input_string=$1
    dummy_load_watt=$1

    if [ "$input_string"  == "1.0" ]; then
        dummy_load=0x0
    elif [ "$input_string"  == "1.5" ]; then
        dummy_load=0x1
    elif [ "$input_string"  == "2.0" ]; then
        dummy_load=0x3
    elif [ "$input_string"  == "2.5" ]; then
        dummy_load=0x7
    elif [ "$input_string"  == "3.0" ]; then
        dummy_load=0xf
    elif [ "$input_string"  == "3.5" ]; then
        dummy_load=0x1f
    elif [ "$input_string"  == "4.0" ]; then
        dummy_load=0x3f
    elif [ "$input_string"  == "4.5" ]; then
        dummy_load=0x7f
    elif [ "$input_string"  == "5.0" ]; then
        dummy_load=0xff
    else
        echo "  Invalid Module dummy load value!"
        Help_Message
        exit 1
    fi
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
    echo "  [MFG] Module Control help message:"
    echo "    Ex: ./module_voltage_control.sh [1.0/1.5/2.0/2.5/3.0/3.5/4.0/4.5/5.0 (W)]"
    echo ""
}

#
# Main
#
Input_Help $1

if (( $#  < 1 )); then
    echo "  Need at least 1 parameter!"
    Help_Message
    exit 1
else
    Input_Check $1
fi

echo "    Module Dummy Load Setting ..."

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
    QSFP_Loading_Set $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR1_REG 8 $CPLD_B_MODULE_MCR_REG 0 1   # QSFP-1~7
    QSFP_Loading_Set $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 4 $CPLD_B_MODULE_MCR_REG 8 8   # QSFP-8~12
    QSFP_Loading_Set $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 8 $CPLD_A_MODULE_MCR_REG 0 13   # QSFP-13~20
    QSFP_Loading_Set $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 8 $CPLD_C_MODULE_MCR_REG 0 21  # QSFP-21~28
    QSFP_Loading_Set $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG 4 $CPLD_C_MODULE_MCR_REG 8 29  # QSFP-29~32
elif [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
    # SFP_Loading_Set $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR_REG 12 $CPLD_B_MODULE_MCR_REG 1 1    # SFP-1~12
    # SFP_Loading_Set $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 24 $CPLD_A_MODULE_MCR_REG 1 13   # SFP-13~36
    # SFP_Loading_Set $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 12 $CPLD_C_MODULE_MCR_REG 1 37  # SFP-37~48
    QSFP_Loading_Set $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG $QSFP_PORTS_AMOUNT $CPLD_C_MODULE_MCR_REG 13 49   # QSFP-49~54
elif [[ "$PROJECT_NAME" == "JAGUAR" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    # SFP_Loading_Set $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR1_REG 8 $CPLD_B_MODULE_MCR_REG 1 1    # SFP-1~8
    # SFP_Loading_Set $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 4 $CPLD_B_MODULE_MCR_REG 9 9    # SFP-9~12
    # SFP_Loading_Set $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 28 $CPLD_A_MODULE_MCR_REG 1 13   # SFP-13~40
    # SFP_Loading_Set $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 8 $CPLD_C_MODULE_MCR_REG 1 41   # SFP-41~48
    QSFP_Loading_Set $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG $QSFP_PORTS_AMOUNT $CPLD_C_MODULE_MCR_REG 9 49    # QSFP-49~56
elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
    echo " ### not support yet " #####
fi

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
