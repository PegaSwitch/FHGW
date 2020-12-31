#!/bin/bash

#################################################################################
# This script is for EDVT 4C-component test use.
# Test each I2C bus read/write access, fan board access, ports detect, system LED
# $1 is test times in second, 0 = infinite loop ; n = how long (n seconds later)
# $2 test Round , default 0
# $3 cycle number
#################################################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

FB_MCU_FAN_A=0x40
FB_MCU_LED_MODE_CONTROL_MANUAL_REG=0x30
FB_MCU_LED_MODE_CONTROL_AUTO_REG=0x31
FB_MCU_LED_MODE_AMBER_ON_REG=0x51
MB_MCU_SMARTFAN_SET_REG=0x12
PSU_FAN_SPEED_REG=0x90
ITEM_TEST_GAP_TIME=1500000     # in ms
ROUND_TEST_GAP_TIME=10   # in second

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

function System_LED_Control ()
{
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_SYSTEM_LED
    sys_led=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG ; } 2>&1 )
    write_data=$(( ( $sys_led & 0x1f ) | $CPLD_LEDCR1_VALUE_SYSTEM_ERROR_BLINK ))       # make system led amber blink
    Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $write_data
    sleep 2
    read_data=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG ; } 2>&1 )
    if (( $read_data == $write_data )); then
        echo " # CPLD i2c access PASS" &>> $test_log
    else
        printf "  error data : w = 0x%x , r = 0x%x \n" $write_data $read_data &>> $test_log
        echo " # CPLD i2c access FAIL" &>> $test_log
    fi
    write_data=$sys_led
    Write_I2C_Device_Node $I2C_BUS $CPLD_LED_CONTROL $CPLD_LEDCR1_REG $write_data        # resume to origin setting
    usleep $ITEM_TEST_GAP_TIME
}

function MB_SmartFan_Control ()
{
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU
    mcu_smartfan_setting=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_SET_REG ; } 2>&1 )
    write_data=$(( $mcu_smartfan_setting | 0x1 ))     # make [0] enable = 1
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_SET_REG $write_data
    usleep 200000
    read_data=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_SET_REG ; } 2>&1 )
    if (( $read_data == $write_data )); then
        echo " # MCU i2c access PASS" &>>  $test_log
    else
        printf "  error data : w = 0x%x , r = 0x%x \n" $write_data $read_data &>> $test_log
        echo " # MCU i2c access FAIL" &>> $test_log
    fi
    write_data=$mcu_smartfan_setting
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_SET_REG $write_data       # resume to origin setting
    usleep $ITEM_TEST_GAP_TIME
}

function PSU_Detect ()
{
    _psu_sel=$1    # A or B
    if [[ "$_psu_sel" == "A" ]]; then
        _psu_addr=$PSU_A_ADDR
        _present_bit=$CPLD_PSR_A_PRESENT_BIT
        _shift_offset=$SHIFT_PRESENT_A_OFFSET
        _mux_channel=$I2C_MUX_CHANNEL_PSU_A
    elif [[ "$_psu_sel" == "B" ]]; then
        _psu_addr=$PSU_B_ADDR
        _present_bit=$CPLD_PSR_B_PRESENT_BIT
        _shift_offset=$SHIFT_PRESENT_B_OFFSET
        _mux_channel=$I2C_MUX_CHANNEL_PSU_B
    fi

    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_PSU_STATUS
    psu_exist=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_PSR_CONTROL $CPLD_PSR_REG ; } 2>&1 )
    if (( (($psu_exist & $_present_bit ) >> $_shift_offset ) == 0x0)); then    # 0 means exist.
        Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $_mux_channel
        psu_speed=$( { Read_I2C_Device_Node $I2C_BUS $_psu_addr $PSU_FAN_SPEED_REG ; } 2>&1)
        ###  need to control the fan speed, if know how ...
        echo " # PSU-$_psu_sel i2c access PASS" &>>  $test_log
    else
        echo " # PSU-$_psu_sel test skipped because the module not exist." &>> $test_log
    fi
    usleep $ITEM_TEST_GAP_TIME
}

function FB_Led_Control ()
{
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $FB_MCU_FAN_A $FB_MCU_LED_MODE_CONTROL_MANUAL_REG  # set LED mode to manual mode first.
    write_data=$FB_MCU_LED_MODE_AMBER_ON_REG
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $FB_MCU_FAN_A $write_data
    sleep 3
    read_data=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $FB_MCU_FAN_A ; } 2>&1 )            # the value is whole status
    check_amber_status=$(( ( ( $read_data & 0x8 ) >> 3 ) ))                            # [3] = 1 is Amber ON ; = 0 is OFF
    if (( $check_amber_status == 0x1 )); then
        echo " # Fan LED i2c access PASS" &>>  $test_log
    else
        printf "  error data : w = 0x%x , r = 0x%x \n" $write_data $read_data &>> $test_log
        echo " # Fan LED i2c access FAIL" &>> $test_log
    fi
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $FB_MCU_FAN_A $FB_MCU_LED_MODE_CONTROL_AUTO_REG    # LED mode to auto mode.
    usleep $ITEM_TEST_GAP_TIME
}

function Check_SFP ()
{
    mux=$1
    mux_channel=$2
    cpld_address=$3
    sfp_status_reg=$4
    data_absent=$5        # 0x3f / 0x0f / 0xff
    ports_perRound=$6
    scl_control_reg=$7
    scl_control_data=$8

    ## Check present pin
    Write_I2C_Device_Node $I2C_BUS $mux $I2C_MUX_REG $mux_channel                # change MUX 's channel.
    for (( statusReg = $sfp_status_reg , index = 0 ; statusReg < ( $sfp_status_reg + ( $ports_perRound / 2 )) ; statusReg++ , index++ ))
    do
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_address $statusReg ; } 2>&1 )
        data=$data_result
        if (( ( $data == 0xff ) || (( $data & 0x11 ) == 0x11 ) )); then
            # echo "  # NO SFP modules inserted on these 2 port." &>> $test_log
            no_SFP_insert_count=$(( $no_SFP_insert_count + 1 ))
        else
            ## Read it's EEPROM
            read_data_control=$( { Read_I2C_Device_Node $I2C_BUS $cpld_address $scl_control_reg ; } 2>&1 )
            for (( portIndex = 0 ; portIndex < 2 ; portIndex++ ))
            do
                if (( (( $data & 0x1 ) == 0x0 && portIndex == 0 ) || (( $data & 0x10 ) == 0x0 && portIndex == 1 ) )); then
                    write_data_control=$(( 0x00 | ( $scl_control_data + (2 * $index + $portIndex ) ) ))
                    Write_I2C_Device_Node $I2C_BUS $cpld_address $scl_control_reg $write_data_control    # switch SCL control bus to the SFP
                    eeprom=$( { Read_I2C_Device_Node $I2C_BUS $MODULE_EEPROM_ADDR 0x0 ; } )                        # read 1st byte of EEPROM of SFP module
                    if [[ $eeprom == *"Error: Read failed"* ]]; then
                        printf " # SFP i2c access FAIL on port %d\n" $portNum &>> $test_log
                    else
                        ## Different port number shown on different DUT.
                        if (( $mux_channel == 0x5 )); then
                            portNum=$(( 2 * $index + 1 + $portIndex ))
                        elif (( $mux_channel == 0x4 )); then
                            portNum=$(( 12 + ( 2 * $index + 1 + $portIndex ) ))
                        else     # mux_channel = 0x6
                            portNum=$(( 36 + ( 2 * $index + 1 + $portIndex ) ))
                        fi
                        printf "  SFP %d has inserted, eeprom value is 0x%x\n" $portNum $eeprom  &>> $test_log
                    fi
                fi
            done
            Write_I2C_Device_Node $I2C_BUS $cpld_address $scl_control_reg $read_data_control     # resume SCL control bus to all disconnect.
        fi
        usleep $I2C_ACTION_DELAY
    done

    ## all SFP ports detection done.
    if (( $no_SFP_insert_count == $(( SFP_PORTS_AMOUNT / 2 )) )); then
        echo "  # SFP I2C detect SKIP because NO SFP modules inserted." &>> $test_log
    fi
}

function Check_QSFP ()
{
    mux=$1
    mux_channel=$2
    cpld_address=$3
    qsfp_status_reg=$4
    data_absent=$5        # 0x3f / 0x0f / 0xff
    ports_perRound=$6
    scl_control_reg=$7
    scl_control_data=$8

    ## Check present pin
    Write_I2C_Device_Node $I2C_BUS $mux $I2C_MUX_REG $mux_channel                # change MUX 's channel.
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $cpld_address $qsfp_status_reg ; } 2>&1 )
    data=$data_result
    if (( $data == $data_absent )); then
        if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then               # all 32 QSFP ports no plug-in
            qsfp_5part_bugatti=$(( $qsfp_5part_bugatti + 1 ))
            if (( $qsfp_5part_bugatti == 5 )); then
                echo "  # QSFP i2c detect SKIP because NO QSFP modules inserted." &>> $test_log
            fi
        else
            echo "  # QSFP i2c detect SKIP because NO QSFP modules inserted." &>> $test_log
        fi
    else
        ## for Porsche, enable all QSFP's module select bit first.(default value = 0x3f) !!!!!!!!!! need ? 0x05 select already @@ need check !!!!
        if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
            Write_I2C_Device_Node $I2C_BUS $cpld_address 0x17 0x00
        fi

        for (( index = 0 ; index < $ports_perRound ; index += 1 ))
        do
            offset=$index
            if (( (($data >> $offset) & 0x1 ) == 0x0)); then
                ## Read it's EEPROM
                read_data_control=$( { Read_I2C_Device_Node $I2C_BUS $cpld_address $scl_control_reg ; } 2>&1 )
                if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
                    write_data_control=$(( 0x00 | ( $scl_control_data + $index ) ))
                else
                    write_data_control=$(( $scl_control_data + $index ))
                fi
                Write_I2C_Device_Node $I2C_BUS $cpld_address $scl_control_reg $write_data_control    # switch SCL control bus to the QSFP
                eeprom=$( { Read_I2C_Device_Node $I2C_BUS $MODULE_EEPROM_ADDR 0x0 ; } )                        # read 1st byte of EEPROM of QSFP module
                if [[ $eeprom == *"Error: Read failed"* ]]; then
                    echo " # QSFP i2c access FAIL" &>> $test_log
                else
                    ## Different port number shown on different DUT.
                    if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
                        if (( $mux_channel == $I2C_MUX_B_CHANNEL_1 )); then
                            portNum=$(( $scl_control_data + $offset + 1 ))
                        elif (( $mux_channel == $I2C_MUX_B_CHANNEL_0 )); then
                            portNum=$(( 12 + $scl_control_data + $offset + 1 ))
                        else     # mux_channel = $I2C_MUX_B_CHANNEL_2
                            portNum=$(( 20 + $scl_control_data + $offset + 1 ))
                        fi
                    else
                        portNum=$(( 48 + $offset + 1 ))
                    fi
                    printf "  QSFP %d has inserted, eeprom value is 0x%x\n" $portNum $eeprom  &>> $test_log
                fi
                Write_I2C_Device_Node $I2C_BUS $cpld_address $scl_control_reg $read_data_control     # resume SCL control bus to all disconnect.
            fi
            usleep $I2C_ACTION_DELAY
        done

        ## all QSFP ports detection done.
        if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
            qsfp_5part_bugatti=$(( $qsfp_5part_bugatti + 1 ))
            if (( $qsfp_5part_bugatti == 5 )); then
                echo " # QSFP i2c access PASS" &>> $test_log
            fi
        else
            echo " # QSFP i2c access PASS" &>> $test_log
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

function Log_Name_Check() # $1: testCycle , $2: testRound
{
    if [ ! -z "$1" ]; then
        this_cycle=$1
        cycle_log="$LOG_PATH_I2C/i2c_bus_test_cycle_$1.log";
        if [ ! -z "$2" ]; then
            this_round=$2
            test_log="$LOG_PATH_I2C/i2c_bus_test_$1_$2.log";
        else
            test_log="$LOG_PATH_I2C/i2c_bus_test_$1.log";
        fi
    else
        cycle_log="$LOG_PATH_I2C/i2c_bus_test_cycle.log";
        test_log="$LOG_PATH_I2C/i2c_bus_test.log"
    fi

    ## if older exist, remove it first.
    if [ -f "$test_log" ]; then rm "$test_log"; fi
}

Log_Name_Check $2 $3

### Start the test ###
printf "\n ==== I2C bus test Start ====\n" |& tee -a $test_log
timestamp |& tee -a $test_log

round_index=1
no_SFP_insert_count=0

if [[ -z "$1" ]]; then
    ## only execute once, so set 1 sec for fun
    end_time=$(($(date +%s) + 2 ))
else
    if (( $1 == 0 )); then
        end_time=$(($(date +%s) + 2592000 ))    # 30 days = 2592000 sec
    else
        if [ ! -z "$2" ] && [ ! -z "$3" ]; then    ## might be PT-4C mode
            end_time_after_buffer=$(( $1 - ( $DIAG_I2C_TEST_CHECK_BUFFER_TIME * 60 ) ))
            end_time=$(($(date +%s) + $end_time_after_buffer ))
        else
            end_time=$(($(date +%s) + $1 ))
        fi
    fi
fi

while (($(date +%s) < $end_time )) ;
do
    printf " ---- Round %d ----\n" $round_index &>> $test_log
    timestamp &>> $test_log

    ### PSU-A & PSU-B detection
    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    PSU_Detect "A"
    PSU_Detect "B"

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi

    ### MCU control, with configure SMART_FAN_SETTING (0x12) enable/disable pin.
    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    MB_SmartFan_Control

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi

    ### System LED blink green
    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    System_LED_Control

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi

    ### FAN LED (A)
    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    FB_Led_Control

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi

    ### SFP & QSFP EEPROM
    bash $MFG_SOURCE_DIR/module_eeprom_read.sh $test_log "i2c-test"
    usleep $ITEM_TEST_GAP_TIME

    ### do EEPROM of main board read/write test. (write value 0x88 at address 0xfe)
    bash $MFG_SOURCE_DIR/mb_eeprom_test.sh 0xfe 0x88 &>> $test_log
    usleep $ITEM_TEST_GAP_TIME

    ### call hardware-monitor to measure current status.
    sleep 1
    bash $MFG_SOURCE_DIR/hw_monitor.sh 1 1 $2 #&

    ### FW version check
    bash $MFG_SOURCE_DIR/fw_version_check.sh $2 $round_index

    ### call QSFP EEPROM dump per hour
    if (( 0 )); then
        sleep 5
        if (( $round_index % 60 == 0 )); then    # Bugatti2 per round 36 second, so 1 hr=3600 sec, almost 60 round.
            bash $MFG_SOURCE_DIR/module_eeprom_read.sh $test_log
            usleep $ITEM_TEST_GAP_TIME
        fi
    fi

    sleep $ROUND_TEST_GAP_TIME

    round_index=$(( $round_index +1 ))
    printf " \n" &>> $test_log
done

timestamp |& tee -a $test_log
printf " ==== I2C bus test done ====\n\n" |& tee -a $test_log

## parse result log
check_result=$( { grep -n "FAIL" "$test_log" ; } 2>&1 )
if [ ! -z "$check_result" ]; then
    echo " # Round # I2C Test Result : FAIL" >> $test_log
    echo "Round $this_round I2C Test Result : FAIL" >> $cycle_log
else
    echo " # Round # I2C Test Result : PASS" >> $test_log
    echo "Round $this_round I2C Test Result : PASS" >> $cycle_log
fi
