#! /bin/bash
# This script is to monitor modules' temperature

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

request_value=0x50
i2c_enable_value=0x00
i2c_disable_value=0xff
lpm_enable_value=0xff
lpm_disable_value=0x00
request_interrupt_status_normal_pega=0xff
request_interrupt_status_active_pega=0x00
request_interupt_bit_normal_pega=0x1
request_interupt_bit_active_pega=0x0

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

function SFP_Control_Signal_Check ()
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
        read_data_control=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg ; } 2>&1 )

        for (( portIndex = 0 ; portIndex < 2 ; portIndex++ ))
        do
            portNum=$(( port_start + ( 2 * $index ) + $portIndex ))
            port_fail_flag=$PASS

            ## check ModPrsL status.
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $statusReg 0x88    # set 2 Modules' Transmit Disable.
            data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $statusReg ; } 2>&1 )
            data=$data_result
            if (( $data_result != 0xee )); then
                if (( (( $data & 0x1 ) == 0x1 && portIndex == 0 ) || (( $data & 0x10 ) == 0x10 && portIndex == 1 ) )); then
                    printf "\tPort %d ModPrsL  is in trouble !!!\n" $portNum
                    port_fail_flag=$FAIL
                fi
            fi
            usleep $I2C_ACTION_DELAY

            ## check Rx_LOS / Tx_FAULT status
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $statusReg 0x00    # set 2 Modules' Transmit Enable.
            data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $statusReg ; } 2>&1 )
            data=$data_result
            if (( $data_result != 0x00 )); then
                if (( (( $data & 0x2 ) == 0x2 && portIndex == 0 ) || (( $data & 0x20 ) == 0x20 && portIndex == 1 ) )); then
                    printf "\tPort %d Rx_LOS   is in trouble !!!\n" $portNum
                    port_fail_flag=$FAIL
                fi

                if (( (( $data & 0x4 ) == 0x4 && portIndex == 0 ) || (( $data & 0x40 ) == 0x40 && portIndex == 1 ) )); then
                    printf "\tPort %d Tx_FAULT is in trouble !!!\n" $portNum
                    port_fail_flag=$FAIL
                fi
            fi

            ## Enable it's EEPROM WP.
            write_data_control=$(( 0x00 | ( $zsmcr_data + (2 * $index + $portIndex ) ) ))
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $write_data_control    # switch SCL control bus to the QSFP
            ## write data first, prevent no data in there before.
            Write_I2C_Device_Node $I2C_BUS $MODULE_EEPROM_ADDR 0x0 $request_value
            ## Try to get Modules EEPROM
            data_result=$( { i2cget -y $I2C_BUS $MODULE_EEPROM_ADDR 0x0 ; } 2>&1 )      ## 20200921 Due to BMC v3 no support modules' EEPROM (0x50), need to force use i2cget command
            data=$data_result
            if [[ "$FLAG_USE_IPMI" == "$FALSE" && "$data_result" == *"Error: Read failed"* ]] || [[ "$FLAG_USE_IPMI" == "$TRUE" && "$data_result" == "0x00" ]]; then
                printf "\tPort %d VCCR_3V3 or VCCT_3V3 or RS0* or RS1* might in trouble !!!\n" $portNum
                port_fail_flag=$FAIL
            elif (( $data_result != $request_value )); then
                printf "\tPort %d VCCR_3V3 or VCCT_3V3 or RS0* or RS1* might in trouble !!!\n" $portNum
                port_fail_flag=$FAIL
            fi

            if (( port_fail_flag == $FAIL )); then
                printf "\t # Port %d test FAIL.\n" $portNum
            else
                printf "\t # Port %d test PASS.\n" $portNum
            fi
        done

        Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $read_data_control     # resume SCL control bus to all disconnect.
    done
}

function QSFP_Control_Signal_Check ()
{
    mux_channel=$1
    cpld_addr=$2
    zsrr_reg=$3
    ports_perRound=$4
    zsmcr_reg=$5
    zsmcr_data=$6
    port_start=$7
    qrstr_reg=$8
    qrst_group_sep=$9
    qisrr_reg=${10}
    qmsr_reg=${11}
    qmlpmr_reg=${12}

    if [[ ! -z "$MODULE_TYPE" ]]; then
        ## common fiber modules will hold interrupt pin, so invert pega'module defined value.
        request_interrupt_status_normal=$(( ~ request_interrupt_status_normal_pega ))
        request_interrupt_status_active=$(( ~ request_interrupt_status_active_pega ))
        request_interupt_bit_normal=$(( ~ request_interupt_bit_normal_pega ))
        request_interupt_bit_active=$(( ~ request_interupt_bit_active_pega ))
    else
        request_interrupt_status_normal=$request_interrupt_status_normal_pega
        request_interrupt_status_active=$request_interrupt_status_active_pega
        request_interupt_bit_normal=$request_interupt_bit_normal_pega
        request_interupt_bit_active=$request_interupt_bit_active_pega
    fi

    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $mux_channel     # change MUX 's channel.

    for (( index = 0 ; index < $ports_perRound ; index += 1 ))
    do
        portNum=$(( port_start + $index ))
        port_fail_flag=$PASS

        ## check ModPrsL status.
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsrr_reg ; } 2>&1 )
        data=$data_result
        if (( $data_result != 0x00 )); then    ## 0x00 : all modules inserted
            if (( (($data >> $index) & 0x1 ) == 0x1)); then
                printf "\tPort %d ModPrsL  is in trouble !!!\n" $portNum
                port_fail_flag=$FAIL
            fi
        fi

        ## Set reset pin to default (reset keep low)
        for (( group_sep = $qrstr_reg , r = 0 ; r < $qrst_group_sep ; group_sep++ , r++ ))
        do
            hexVal=$( { echo obase=16"; $group_sep" | bc ; } 2>&1 )
            index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $index_hex 0x00
        done

        ## check INTn status.
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $qisrr_reg ; } 2>&1 )
        data=$data_result
        if (( $data_result != $request_interrupt_status_active )); then
            if (( (($data >> $index) & 0x1 ) == $request_interupt_bit_normal )); then
                printf "\tPort %d INTn  is in trouble !!!\n" $portNum
                port_fail_flag=$FAIL
            fi
        fi

        ## Setting reset pin back to normal
        for (( group_sep = $qrstr_reg , r = 0 ; r < $qrst_group_sep ; group_sep++ , r++ ))
        do
            hexVal=$( { echo obase=16"; $group_sep" | bc ; } 2>&1 )
            index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $index_hex 0x55
        done

        ## check INTn status again to check RSTn write ability.
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $qisrr_reg ; } 2>&1 )
        if (( $data_result != $request_interrupt_status_normal )); then
            if (( (($data >> $index) & 0x1 ) == $request_interupt_bit_active )); then
                printf "\tPort %d RSTn  is in trouble !!!\n" $portNum
                port_fail_flag=$FAIL
            fi
        fi

        ## Set I2C enable first.
        Write_I2C_Device_Node $I2C_BUS $cpld_addr $qmsr_reg $i2c_enable_value

        ## Set Low power mode disable first.
        Write_I2C_Device_Node $I2C_BUS $cpld_addr $qmlpmr_reg $lpm_disable_value

        ## Enable it's EEPROM WP.
        read_data_control=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg ; } 2>&1 )
        if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
            write_data_control=$(( 0x00 | ( $zsmcr_data + $index ) ))
        else
            value=$(( $zsmcr_data + $index ))
            hexVal=$( { echo obase=16"; $value" | bc ; } 2>&1 )
            write_data_control=$( { echo "0x"$hexVal ; } 2>&1 )
        fi
        Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $write_data_control    # switch SCL control bus to the QSFP

        ## PEGA's loopback modules need to write data first, prevent no data in there before.
        if [[ -z "$MODULE_TYPE" ]]; then
            Write_I2C_Device_Node $I2C_BUS $MODULE_EEPROM_ADDR 0x0 $request_value
        fi

        ## Try to get Modules EEPROM data
        data_result=$( { i2cget -y $I2C_BUS $MODULE_EEPROM_ADDR 0x0 ; } 2>&1 )      ## 20200921 Due to BMC v3 no support modules' EEPROM (0x50), need to force use i2cget command
        usleep 350000    ## 20200515 add additional 250ms for prevent I2C arbiter locked.
        if [[ "$FLAG_USE_IPMI" == "$FALSE" && "$data_result" == *"Error: Read failed"* ]] || [[ "$FLAG_USE_IPMI" == "$TRUE" && "$data_result" == "0x00" ]]; then
            printf "\tPort %d VCCR_3V3 or VCCT_3V3 or RS0* or RS1* might in trouble !!!\n" $portNum
            port_fail_flag=$FAIL
        elif [[ "$data_result" != "$request_value" ]] && [[ -z "$MODULE_TYPE" ]]; then
            printf "\tPort %d VCCR_3V3 or VCCT_3V3 or RS0* or RS1* might in trouble !!!\n" $portNum
            port_fail_flag=$FAIL
        fi

        if [[ "$PROJECT_NAME" != "BUGATTI" ]]; then
            ## Set I2C disable to check ModSELn
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $qmsr_reg $i2c_disable_value

            ## Try to get Modules data to make sure ModSELn function
            data_result=$( { i2cget -y $I2C_BUS $MODULE_EEPROM_ADDR 0x0 ; } 2>&1 )  ## 20200921 Due to BMC v3 no support modules' EEPROM (0x50), need to force use i2cget command
            usleep 350000    ## 20200515 add additional 250ms for prevent I2C arbiter locked.
            data=$data_result
            if [[ "$FLAG_USE_IPMI" == "$FALSE" && "$data_result" != *"Error: Read failed"* ]] || [[ "$FLAG_USE_IPMI" == "$TRUE" && "$data_result" != "0x00" ]]; then
                printf "\tPort %d ModSELn might in trouble !!!\n" $portNum
                port_fail_flag=$FAIL
            fi

            ## Restore I2C back to Enable
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $qmsr_reg $i2c_enable_value
            usleep 350000    ## 20200515 add additional 250ms for prevent I2C arbiter locked.

            ## Set Low power mode Enable to check LPMode status
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $qmlpmr_reg $lpm_enable_value

            ## Try to get Modules data to make sure LPMode function
            data_result=$( { i2cget -y $I2C_BUS $MODULE_EEPROM_ADDR 0x0 ; } 2>&1 )  ## 20200921 Due to BMC v3 no support modules' EEPROM (0x50), need to force use i2cget command
            usleep 350000    ## 20200515 add additional 250ms for prevent I2C arbiter locked.
            if [[ -z "$MODULE_TYPE" ]];then
                if [[ "$FLAG_USE_IPMI" == "$FALSE" && "$data_result" != *"Error: Read failed"* ]] || [[ "$FLAG_USE_IPMI" == "$TRUE" && "$data_result" != "0x00" ]]; then    ## PEGA module case
                    printf "\tPort %d LPMode might in trouble !!!\n" $portNum
                    port_fail_flag=$FAIL
                fi
            fi

            ## Reset Low power mode back to Disable
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $qmlpmr_reg $lpm_disable_value
        fi

        ## Show final result
        if (( port_fail_flag == $FAIL )); then
            printf "\t # Port %d test FAIL.\n" $portNum
        else
            printf "\t # Port %d test PASS.\n" $portNum
        fi

        ## resume SCL control bus to all disconnect.
        Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $read_data_control
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
    echo "    Ex: ./mfg_sources/factory_mb_module_connection_check.sh {fiber}"
    echo "    if parameter 'fiber' not exist, test case is for Pegatron lbl ; else verse."
    echo ""
}

function Input_Help()
{
    input_string=$1

    if [[ $input_string == "-h" ]] || [[ $input_string == "-help" ]] || [[ $input_string == "--h" ]] ||
       [[ $input_string == "--help" ]] || [[ $input_string == "?" ]]; then
        Help_Message
        exit 1
    elif [[ ! -z "$input_string" ]]; then
        MODULE_TYPE=$1
    fi
}


#
# Main
#
Input_Help $1

if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi
Mutex_Check_And_Create

printf "\t{ Module Signal Check }\n"

if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then    # last 2 parameters are not support in BUGATTI CPLD, so use none-use value 0xff
    QSFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR1_REG 8 $CPLD_B_MODULE_MCR_REG 0 1 0x09 2 0x05 0xff 0xff   # QSFP-1~7
    QSFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 4 $CPLD_B_MODULE_MCR_REG 8 8 0x0B 1 0x06 0xff 0xff   # QSFP-8~12
    QSFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 8 $CPLD_A_MODULE_MCR_REG 0 13 0x0C 2 0x08 0xff 0xff   # QSFP-13~20
    QSFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 8 $CPLD_C_MODULE_MCR_REG 0 21 0x09 2 0x05 0xff 0xff  # QSFP-21~28
    QSFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG 4 $CPLD_C_MODULE_MCR_REG 8 29 0x0B 1 0x06 0xff 0xff  # QSFP-29~32
elif [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
    SFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR_REG 12 $CPLD_B_MODULE_MCR_REG 1 1    # SFP-1~12
    SFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 24 $CPLD_A_MODULE_MCR_REG 1 13   # SFP-13~36
    SFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 12 $CPLD_C_MODULE_MCR_REG 1 37  # SFP-37~48
    QSFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG $QSFP_PORTS_AMOUNT $CPLD_C_MODULE_MCR_REG 13 49 $QSFP_QRSTR_REG 2 $QSFP_MISRR_REG $QSFP_QMSR_REG $QSFP_QMLPMR_REG   # QSFP-49~54
elif [[ "$PROJECT_NAME" == "JAGUAR" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    SFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR1_REG 8 $CPLD_B_MODULE_MCR_REG 1 1    # SFP-1~8
    SFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 4 $CPLD_B_MODULE_MCR_REG 9 9    # SFP-9~12
    SFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 28 $CPLD_A_MODULE_MCR_REG 1 13   # SFP-13~40
    SFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 8 $CPLD_C_MODULE_MCR_REG 1 41   # SFP-41~48
    QSFP_Control_Signal_Check $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG $QSFP_PORTS_AMOUNT $CPLD_C_MODULE_MCR_REG 9 49 $QSFP_QRSTR_REG 2 $QSFP_MISRR_REG $QSFP_QMSR_REG $QSFP_QMLPMR_REG    # QSFP-49~56
elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
    echo " ### not support yet " #####
fi

if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
Mutex_Clean
