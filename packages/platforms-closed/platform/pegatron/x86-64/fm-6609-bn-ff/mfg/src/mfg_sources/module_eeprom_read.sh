#!/bin/bash

#################################################################################
# This script is for EDVT to dump out QSFP EEPROM.
# $1 is to assign log path.
#################################################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

WAIT_TIME=150000     # in ms
EEPROM_REQADDR=0x7f

target_port=0
no_SFP_insert_count=0

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

function Log_Name_Check () # $1: log path
{
    if [ ! -z "$1" ]; then
        if [ -n "$(echo "$1" | sed -n "/^[0-9]\+$/p")" ]; then    ## check whether is numeric
            test_target="onlyOnePort"
            target_port=$1
            testLog="$LOG_PATH_I2C/i2c_module_eeprom.log"
             echo "  Please wait ... start checking port $target_port"
        else
            testLog="$1"
        fi
    else
        testLog="$LOG_PATH_I2C/i2c_module_eeprom.log"
        #if [ -f "$testLog" ]; then rm "$testLog"; fi
    fi
}

function Read_Module_EEPROM ()
{
    ## Read EEPROM of each module.
    for (( index = 0 ; index < 4 ; index += 1 ))
    do
        # i2cget -y $I2C_BUS $MODULE_EEPROM_ADDR $EEPROM_REQADDR
        i2cset -y $I2C_BUS $MODULE_EEPROM_ADDR $EEPROM_REQADDR $index
        usleep $I2C_ACTION_DELAY
        usleep $WAIT_TIME
        i2cdump -y $I2C_BUS $MODULE_EEPROM_ADDR b |& tee -a $testLog
        usleep $WAIT_TIME
    done
    i2cset -y $I2C_BUS $MODULE_EEPROM_ADDR $EEPROM_REQADDR 0x0    # resume
    usleep $I2C_ACTION_DELAY
}

function SFP_EEPROM_Get ()
{
    mux_channel=$1
    cpld_addr=$2
    zsrr_reg=$3
    ports_perRound=$4
    zsmcr_reg=$5
    zsmcr_data=$6
    port_start=$7
    data_absent=$8        # 0x3f / 0x0f / 0xff

    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $mux_channel     # change MUX 's channel.

    for (( statusReg = $zsrr_reg , port_index = 0 ; statusReg < ( $zsrr_reg + ( $ports_perRound / 2 )) ; statusReg++ , port_index++ ))
    do
        ## check present pin status.
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $statusReg ; } 2>&1 )
        data=$data_result
        if [[ "$test_target" == "i2c-test" ]] && (( ( $data == 0xff ) || (( $data & 0x11 ) == 0x11 ) )); then
            # echo "  # NO SFP modules inserted on these 2 port." &>> $testLog
            no_SFP_insert_count=$(( $no_SFP_insert_count + 1 ))

        else
            read_data_control=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg ; } 2>&1 )
            for (( portIndex = 0 ; portIndex < 2 ; portIndex++ ))
            do
                portNum=$(( port_start + ( 2 * $port_index ) + $portIndex ))

                if [[ "$test_target" == "onlyOnePort" ]] && [[ "$target_port" != "$portNum" ]]; then    ## only want the target port so keep counting
                    continue
                fi

                ## Check modules present, then read its data.
                if (( (( $data & 0x1 ) == 0x0 && portIndex == 0 ) || (( $data & 0x10 ) == 0x0 && portIndex == 1 ) )); then    ## means module insert
                    ## Enable it's EEPROM WP.
                    write_data_control=$(( 0x00 | ( $zsmcr_data + (2 * $port_index + $portIndex ) ) ))
                    Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $write_data_control    # switch SCL control bus to the SFP

                    if [[ "$test_target" == "i2c-test" ]]; then
                        eeprom=$( { Read_I2C_Device_Node $I2C_BUS $MODULE_EEPROM_ADDR 0x0 ; } )                        # read 1st byte of EEPROM of SFP module
                        if [[ $eeprom == *"Error: Read failed"* ]]; then
                            printf " # SFP i2c access FAIL on port %d\n" $portNum &>> $testLog
                        else
                            printf "  SFP %d has inserted, eeprom value is 0x%x\n" $portNum $eeprom  &>> $testLog
                        fi
                    else    ## test_target = "all"
                        echo " <<< Port " $portNum " Dump EERPOM >>>" |& tee -a $testLog
                        ## get Modules' EEPROM data
                        Read_Module_EEPROM
                    fi

                else    ## another module not exist
                    if [[ "$test_target" != "i2c-test" ]]; then        # "i2c-test " case dont need to show not inserted port msg
                        printf "\tPort %d is NOT Present.\n" $portNum |& tee -a $testLog
                    fi
                fi
                usleep $I2C_ACTION_DELAY

                if [[ "$test_target" == "onlyOnePort" ]]; then    ## target port mission done, so quit
                    break
                fi

            done
            Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $read_data_control     # resume SCL control bus to all disconnect.
        fi
        usleep $I2C_ACTION_DELAY
    done

    ## all SFP ports detection done.
    if [[ "$test_target" == "i2c-test" ]] && (( $no_SFP_insert_count == $(( SFP_PORTS_AMOUNT / 2 )) )); then
        echo "  # SFP I2C detect SKIP because NO SFP modules inserted." &>> $testLog
    fi
}

function QSFP_EEPROM_Get ()
{
    mux_channel=$1
    cpld_addr=$2
    zsrr_reg=$3
    ports_perRound=$4
    zsmcr_reg=$5
    zsmcr_data=$6
    port_start=$7
    data_absent=$8        # 0x3f / 0x0f / 0xff

    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $mux_channel     # change MUX 's channel.

    ## check present pin status.
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsrr_reg ; } 2>&1 )
    data=$data_result

    if [[ "$data" == "$data_absent" ]] && [[ "$test_target" == "i2c-test" ]]; then
        if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then               # all 32 QSFP ports no plug-in
            qsfp_5part_bugatti=$(( $qsfp_5part_bugatti + 1 ))
            if (( $qsfp_5part_bugatti == 5 )); then
                echo "  # QSFP i2c detect SKIP because NO QSFP modules inserted." &>> $testLog
            fi
        else
            echo "  # QSFP i2c detect SKIP because NO QSFP modules inserted." &>> $testLog
        fi
    else
        if [[ "$PROJECT_NAME" == "PORSCHE" ]] ; then
            Write_I2C_Device_Node $I2C_BUS $cpld_addr 0x17 0x00
        fi

        for (( port_index = 0 ; port_index < $ports_perRound ; port_index += 1 ))
        do
            portNum=$(( port_start + $port_index ))

            if [[ "$test_target" == "onlyOnePort" ]] && [[ "$target_port" != "$portNum" ]]; then    ## only want the target port so keep counting
                continue
            fi

            ## Check modules present, then read its data.
            if (( (($data >> $port_index) & 0x1 ) == 0x0)); then    ## means module insert
                ## Eable it's EEPROM WP.
                read_data_control=$( { Read_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg ; } 2>&1 )
                if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
                    write_data_control=$(( 0x00 | ( $zsmcr_data + $port_index ) ))
                else
                    write_data_control=$(( $zsmcr_data + $port_index ))
                fi
                Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $write_data_control    # switch SCL control bus to the QSFP

                if [[ "$test_target" == "i2c-test" ]]; then
                    eeprom=$( { Read_I2C_Device_Node $I2C_BUS $MODULE_EEPROM_ADDR 0x0 ; } )                        # read 1st byte of EEPROM of QSFP module
                    if [[ $eeprom == *"Error: Read failed"* ]]; then
                        echo " # QSFP $portNum i2c access FAIL" &>> $testLog
                    else
                        printf "  QSFP %d has inserted, eeprom value is 0x%x\n" $portNum $eeprom  &>> $testLog
                    fi
                else
                    echo " <<< Port " $portNum " Dump EERPOM >>>" |& tee -a $testLog
                    ## get Modules' EEPROM data
                    Read_Module_EEPROM
                fi
                Write_I2C_Device_Node $I2C_BUS $cpld_addr $zsmcr_reg $read_data_control     # resume SCL control bus to all disconnect.
            else    ## module not exist
                if [[ "$test_target" != "i2c-test" ]]; then    # "i2c-test " case dont need to show not inserted port msg
                    printf "\tPort %d is NOT Present.\n" $portNum |& tee -a $testLog
                fi
            fi
            usleep $I2C_ACTION_DELAY

            if [[ "$test_target" == "onlyOnePort" ]]; then    ## target port mission done, so quit
                break
            fi
        done

        ## all QSFP ports detection done.
        if [[ "$test_target" == "i2c-test" ]]; then
            if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
                qsfp_5part_bugatti=$(( $qsfp_5part_bugatti + 1 ))
                if (( $qsfp_5part_bugatti == 5 )); then
                    echo " # QSFP i2c access PASS" &>> $testLog
                fi
            else
                echo " # QSFP i2c access PASS" &>> $testLog
            fi
        fi
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


if [[ ! -z "$2" ]]; then
    test_target=$2    # 'i2c-test'
else
    test_target="all"
fi

Log_Name_Check $1

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
    QSFP_EEPROM_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR1_REG 8 $CPLD_B_MODULE_MCR_REG 0 1 0xff   # QSFP-1~7
    QSFP_EEPROM_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 4 $CPLD_B_MODULE_MCR_REG 8 8 0x0f   # QSFP-8~12
    QSFP_EEPROM_Get $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 8 $CPLD_A_MODULE_MCR_REG 0 13 0xff   # QSFP-13~20
    QSFP_EEPROM_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 8 $CPLD_C_MODULE_MCR_REG 0 21 0xff  # QSFP-21~28
    QSFP_EEPROM_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG 4 $CPLD_C_MODULE_MCR_REG 8 29 0x0f  # QSFP-29~32
elif [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
    SFP_EEPROM_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR_REG 12 $CPLD_B_MODULE_MCR_REG 1 1 0x11    # SFP-1~12
    SFP_EEPROM_Get $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 24 $CPLD_A_MODULE_MCR_REG 1 13 0x11   # SFP-13~36
    SFP_EEPROM_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 12 $CPLD_C_MODULE_MCR_REG 1 37 0x11  # SFP-37~48
    QSFP_EEPROM_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG $QSFP_PORTS_AMOUNT $CPLD_C_MODULE_MCR_REG 13 49 0x3f   # QSFP-49~54
elif [[ "$PROJECT_NAME" == "JAGUAR" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    SFP_EEPROM_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR1_REG 8 $CPLD_B_MODULE_MCR_REG 1 1 0xff    # SFP-1~8
    SFP_EEPROM_Get $I2C_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 4 $CPLD_B_MODULE_MCR_REG 9 9 0xff    # SFP-9~12
    SFP_EEPROM_Get $I2C_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_A_MSRR_REG 28 $CPLD_A_MODULE_MCR_REG 1 13 0xff   # SFP-13~40
    SFP_EEPROM_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR1_REG 8 $CPLD_C_MODULE_MCR_REG 1 41 0xff   # SFP-41~48
    QSFP_EEPROM_Get $I2C_MUX_B_CHANNEL_2 $CPLD_C_ADDR $CPLD_C_MSRR2_REG $QSFP_PORTS_AMOUNT $CPLD_C_MODULE_MCR_REG 9 49 0xff    # QSFP-49~56
elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
    echo " ### not support yet " #####
fi

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
