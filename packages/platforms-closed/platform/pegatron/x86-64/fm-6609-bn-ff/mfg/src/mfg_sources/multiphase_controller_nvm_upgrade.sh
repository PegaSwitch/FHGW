#!/bin/bash

######################################################################
## This script is to update setting of Multicase controller - TPS53679
##  v20200602 set 1V1 OCP to 15A(warning) and 18A(fault)
##  v20200605 add setting power core 0V9 to 0V93.
######################################################################

mfg_debug=0

declare -a array_pmbus_value

function Register_Define ()
{
    I2C_BUS=0
    I2C_MUX_REG=0x0
    I2C_ACTION_DELAY=100000
    I2C_MUTEX_NODE="/tmp/i2c-bus-mutex"

    ## Below defined is based on Gemini layout design.
    I2C_MUX_PMBUS=0x72
    I2C_MUX_CHANNEL_PMBUS=0x6
    PMBUS_MB_A_ADDR=0x60
}

function NVM_Value_Define ()
{
    ## TPS53679 spec defined
    MPC_TPS536XX_DEVICE_ID_REG=0xAD
    MPC_TPS53679_ID=0x79
    MPC_TPS536XX_PAGE_REG=0x0
    MPC_TPS536XX_VOUT_COMMAND_REG=0x21
    MPC_TPS536XX_VOUT_MAX_REG=0x24
    MPC_TPS536XX_VOUT_MARGIN_HIGH_REG=0x25
    MPC_TPS536XX_VOUT_MARGIN_LOW_REG=0x26
    MPC_TPS536XX_VOUT_MIN_REG=0x2b
    MPC_TPS536XX_USER_DATA_00_REG=0xb0
    MPC_TPS536XX_USER_DATA_01_REG=0xb1
    MPC_TPS536XX_USER_DATA_02_REG=0xb2
    MPC_TPS536XX_USER_DATA_03_REG=0xb3
    MPC_TPS536XX_USER_DATA_04_REG=0xb4
    MPC_TPS536XX_USER_DATA_05_REG=0xb5
    MPC_TPS536XX_USER_DATA_06_REG=0xb6
    MPC_TPS536XX_USER_DATA_07_REG=0xb7
    MPC_TPS536XX_USER_DATA_08_REG=0xb8
    MPC_TPS536XX_USER_DATA_09_REG=0xb9
    MPC_TPS536XX_USER_DATA_10_REG=0xba
    MPC_TPS536XX_USER_DATA_11_REG=0xbb
    MPC_TPS536XX_USER_DATA_12_REG=0xbc
    MPC_TPS536XX_NVM_CHECKSUM_REG=0x9E
    MPC_TPS536XX_STORE_DEFAULT_ALL_REG=0x11

    ## Below value is based on 20200605 Power FW of TI provided.
    TPS536XX_NVM_CHECKSUM="1b0ce447"       # in v.20200602 - 0x1b09e647
    VALUE_VOUT_MAX_RAIL1=0x002e            # 0x002e = 0.950V ; in v.20200602 - 0x002c = 0.930 V
    VALUE_VOUT_MAX_RAIL2=0x0043            # 1.160 V
    VALUE_VOUT_COMMAND_RAIL1=0x002c        # 0x002c = 0.930V ; in v.20200602 - 0x0029 = 0.900 V
    VALUE_VOUT_COMMAND_RAIL2=0x003d        # 1.100 V
    VALUE_VOUT_MARGIN_HIGH_RAIL1=0x0000    # 0.000 V
    VALUE_VOUT_MARGIN_HIGH_RAIL2=0x0000    # 0.000 V
    VALUE_VOUT_MARGIN_LOW_RAIL1=0x0000     # 0.000 V
    VALUE_VOUT_MARGIN_LOW_RAIL2=0x0000     # 0.000 V
    VALUE_VOUT_MIN_RAIL1=0x0026            # 0.870 V
    VALUE_VOUT_MIN_RAIL2=0x0037            # 1.040 V
    VALUE_USER_DATA_00=(1b 00 32 b9 21 f2)
    VALUE_USER_DATA_01=(00 00 00 00 00 40)
    VALUE_USER_DATA_02=(89 04 00 00 00 50)
    VALUE_USER_DATA_03=(04 00 10 0a 00 80)
    VALUE_USER_DATA_04=(09 09 c3 25 c7 77)
    VALUE_USER_DATA_05=(28 c8 c3 2c 3d 20) # v0605 = 0x2c means set power core 0V9 to 0V93 ; in v.20200602 - [2]=0x29
    VALUE_USER_DATA_06=(85 1a 11 12 e8 7f)
    VALUE_USER_DATA_07=(80 ff 09 00 10 ff)
    VALUE_USER_DATA_08=(00 02 00 00 00 94)
    VALUE_USER_DATA_09=(00 01 70 84 80 80)
    VALUE_USER_DATA_10=(00 66 2e c0 c1 8d)
    VALUE_USER_DATA_11=(08 22 20 c0 8f e1)
    VALUE_USER_DATA_12=(40 50 82 20 ff 01)
}

function Debug_And_Print_Value ()
{
    echo "  [Debug] PMBus IC : $device_id"
    echo "  [Debug] VOUT_MAX         #1 value : $vout_max_rail1"
    echo "  [Debug] VOUT_COMMAND     #1 value : $vout_cmd_rail1"
    echo "  [Debug] VOUT_MARGIN_HIGH #1 value : $vout_margin_high_rail1"
    echo "  [Debug] VOUT_MARGIN_LOW  #1 value : $vout_margin_low_rail1"
    echo "  [Debug] VOUT_MIN         #1 value : $vout_min_rail1"
    echo "  [Debug] USER_DATA_00 value : 0x$userdata_00"
    echo "  [Debug] USER_DATA_01 value : 0x$userdata_01"
    echo "  [Debug] USER_DATA_02 value : 0x$userdata_02"
    echo "  [Debug] USER_DATA_03 value : 0x$userdata_03"
    echo "  [Debug] USER_DATA_04 value : 0x$userdata_04"
    echo "  [Debug] USER_DATA_05 value : 0x$userdata_05"
    echo "  [Debug] USER_DATA_06 value : 0x$userdata_06"
    echo "  [Debug] USER_DATA_07 value : 0x$userdata_07"
    echo "  [Debug] USER_DATA_08 value : 0x$userdata_08"
    echo "  [Debug] USER_DATA_09 value : 0x$userdata_09"
    echo "  [Debug] USER_DATA_10 value : 0x$userdata_10"
    echo "  [Debug] USER_DATA_11 value : 0x$userdata_11"
    echo "  [Debug] USER_DATA_12 value : 0x$userdata_12"
    echo "  [Debug] VOUT_MAX         #2 value : $vout_max_rail2"
    echo "  [Debug] VOUT_COMMAND     #2 value : $vout_cmd_rail2"
    echo "  [Debug] VOUT_MARGIN_HIGH #2 value : $vout_margin_high_rail2"
    echo "  [Debug] VOUT_MARGIN_LOW  #2 value : $vout_margin_low_rail2"
    echo "  [Debug] VOUT_MIN         #2 value : $vout_min_rail2"
    echo "  [Debug] NVM checksum : 0x$nvm_checksum"
}

function Write_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3
    i2c_data=$4

    if (( $FLAG_USE_IPMI == 0 )); then
        i2cset -y $i2c_bus $i2c_device $i2c_register $i2c_data
    else
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_SET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE $i2c_data ; } 2>&1 )
    fi
    usleep $I2C_ACTION_DELAY
}

function I2C_Mutex_Check_And_Create()
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

function I2C_Mutex_Clean()
{
    rm $I2C_MUTEX_NODE
    sync
    usleep 100000
}

function Exit_NVM_Update ()
{

    ## for debug usage
    if (( $mfg_debug )); then
        Debug_And_Print_Value
    fi

    ## Switch to default channel 0
    Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_PAGE_REG 0x0

    ## Switch CPLD path back.
    i2cset -y $I2C_BUS $I2C_MUX_PMBUS $I2C_MUX_REG 0x0
    usleep $I2C_ACTION_DELAY


    I2C_Mutex_Clean
    if (( $FLAG_USE_IPMI == 1 )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi

    exit 1
}

## For outside usage, please use case 'else' to get value defined.
if (( 1 )); then
    source /home/root/mfg/mfg_sources/platform_detect.sh
else
    Register_Define
    FLAG_USE_IPMI=0    ## !!! Please update this value to 1, if BMC is on board.
fi

NVM_Value_Define

I2C_Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == 1 )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

## Switch CPLD path to TPS53679
i2cset -y $I2C_BUS $I2C_MUX_PMBUS $I2C_MUX_REG $I2C_MUX_CHANNEL_PMBUS
usleep $I2C_ACTION_DELAY

## Check ID (1-byte) is TPS53679 (0x79) first.
read_id=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_DEVICE_ID_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 1 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_id | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
done
device_id="0x${array_pmbus_value[0]}"
if [ "$device_id" != "$MPC_TPS53679_ID" ]; then
    echo " # Fail ... PMBus IC ( 0x${array_pmbus_value[0]} ) is not mapping to target ( $MPC_TPS53679_ID )"
    Exit_NVM_Update
fi

## Set to channel A (page 0)
Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_PAGE_REG 0x0

## Access VOUT_MAX [Rail#1]
Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MAX_REG $VALUE_VOUT_MAX_RAIL1 w

vout_max_rail1=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MAX_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_max_rail1" != "$VALUE_VOUT_MAX_RAIL1" ]; then
    echo " # Fail ... Vout_max setting ( $vout_max_rail1 ) is not mapping to target ( $VALUE_VOUT_MAX_RAIL1 )"
    Exit_NVM_Update
fi


## Access USER_DATA_00 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_00[@]} ; i++ ))
do
    to_write_userdata_00="${to_write_userdata_00} 0x${VALUE_USER_DATA_00[$i]}"
    userdata_00="${userdata_00}${VALUE_USER_DATA_00[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_00_REG $to_write_userdata_00 s
usleep $I2C_ACTION_DELAY

read_data_00=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_00_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_00 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_00="${read_userdata_00}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_00[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_00 ( 0x${read_userdata_00} ) is not mapping to target ( 0x${userdata_00} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_01 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_01[@]} ; i++ ))
do
    to_write_userdata_01="${to_write_userdata_01} 0x${VALUE_USER_DATA_01[$i]}"
    userdata_01="${userdata_01}${VALUE_USER_DATA_01[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_01_REG $to_write_userdata_01 s
usleep $I2C_ACTION_DELAY

read_data_01=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_01_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_01 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_01="${read_userdata_01}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_01[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_01 ( 0x${read_userdata_01} ) is not mapping to target ( 0x${userdata_01} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_02 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_02[@]} ; i++ ))
do
    to_write_userdata_02="${to_write_userdata_02} 0x${VALUE_USER_DATA_02[$i]}"
    userdata_02="${userdata_02}${VALUE_USER_DATA_02[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_02_REG $to_write_userdata_02 s
usleep $I2C_ACTION_DELAY

read_data_02=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_02_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_02 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_02="${read_userdata_02}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_02[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_02 ( 0x${read_userdata_02} ) is not mapping to target ( 0x${userdata_02} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_03 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_03[@]} ; i++ ))
do
    to_write_userdata_03="${to_write_userdata_03} 0x${VALUE_USER_DATA_03[$i]}"
    userdata_03="${userdata_03}${VALUE_USER_DATA_03[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_03_REG $to_write_userdata_03 s
usleep $I2C_ACTION_DELAY

read_data_03=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_03_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_03 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_03="${read_userdata_03}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_03[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_03 ( 0x${read_userdata_03} ) is not mapping to target ( 0x${userdata_03} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_04 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_04[@]} ; i++ ))
do
    to_write_userdata_04="${to_write_userdata_04} 0x${VALUE_USER_DATA_04[$i]}"
    userdata_04="${userdata_04}${VALUE_USER_DATA_04[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_04_REG $to_write_userdata_04 s
usleep $I2C_ACTION_DELAY

read_data_04=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_04_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_04 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_04="${read_userdata_04}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_04[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_04 ( 0x${read_userdata_04} ) is not mapping to target ( 0x${userdata_04} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_05 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_05[@]} ; i++ ))
do
    to_write_userdata_05="${to_write_userdata_05} 0x${VALUE_USER_DATA_05[$i]}"
    userdata_05="${userdata_05}${VALUE_USER_DATA_05[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_05_REG $to_write_userdata_05 s
usleep $I2C_ACTION_DELAY

read_data_05=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_05_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_05 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_05="${read_userdata_05}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_05[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_05 ( 0x${read_userdata_05} ) is not mapping to target ( 0x${userdata_05} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_06 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_06[@]} ; i++ ))
do
    to_write_userdata_06="${to_write_userdata_06} 0x${VALUE_USER_DATA_06[$i]}"
    userdata_06="${userdata_06}${VALUE_USER_DATA_06[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_06_REG $to_write_userdata_06 s
usleep $I2C_ACTION_DELAY

read_data_06=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_06_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_06 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_06="${read_userdata_06}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_06[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_06 ( 0x${read_userdata_06} ) is not mapping to target ( 0x${userdata_06} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_07 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_07[@]} ; i++ ))
do
    to_write_userdata_07="${to_write_userdata_07} 0x${VALUE_USER_DATA_07[$i]}"
    userdata_07="${userdata_07}${VALUE_USER_DATA_07[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_07_REG $to_write_userdata_07 s
usleep $I2C_ACTION_DELAY

read_data_07=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_07_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_07 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_07="${read_userdata_07}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_07[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_07 ( 0x${read_userdata_07} ) is not mapping to target ( 0x${userdata_07} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_08 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_08[@]} ; i++ ))
do
    to_write_userdata_08="${to_write_userdata_08} 0x${VALUE_USER_DATA_08[$i]}"
    userdata_08="${userdata_08}${VALUE_USER_DATA_08[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_08_REG $to_write_userdata_08 s
usleep $I2C_ACTION_DELAY

read_data_08=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_08_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_08 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_08="${read_userdata_08}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_08[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_08 ( 0x${read_userdata_08} ) is not mapping to target ( 0x${userdata_08} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_09 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_09[@]} ; i++ ))
do
    to_write_userdata_09="${to_write_userdata_09} 0x${VALUE_USER_DATA_09[$i]}"
    userdata_09="${userdata_09}${VALUE_USER_DATA_09[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_09_REG $to_write_userdata_09 s
usleep $I2C_ACTION_DELAY

read_data_09=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_09_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_09 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_09="${read_userdata_09}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_09[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_09 ( 0x${read_userdata_09} ) is not mapping to target ( 0x${userdata_09} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_10 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_10[@]} ; i++ ))
do
    to_write_userdata_10="${to_write_userdata_10} 0x${VALUE_USER_DATA_10[$i]}"
    userdata_10="${userdata_10}${VALUE_USER_DATA_10[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_10_REG $to_write_userdata_10 s
usleep $I2C_ACTION_DELAY

read_data_10=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_10_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_10 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_10="${read_userdata_10}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_10[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_10 ( 0x${read_userdata_10} ) is not mapping to target ( 0x${userdata_10} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_11 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_11[@]} ; i++ ))
do
    to_write_userdata_11="${to_write_userdata_11} 0x${VALUE_USER_DATA_11[$i]}"
    userdata_11="${userdata_11}${VALUE_USER_DATA_11[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_11_REG $to_write_userdata_11 s
usleep $I2C_ACTION_DELAY

read_data_11=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_11_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_11 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_11="${read_userdata_11}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_11[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_11 ( 0x${read_userdata_11} ) is not mapping to target ( 0x${userdata_11} )"
        Exit_NVM_Update
    fi
done

## Access USER_DATA_12 [Rail#1]
for (( i = 0 ; i < ${#VALUE_USER_DATA_12[@]} ; i++ ))
do
    to_write_userdata_12="${to_write_userdata_12} 0x${VALUE_USER_DATA_12[$i]}"
    userdata_12="${userdata_12}${VALUE_USER_DATA_12[$i]}"
done
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_USER_DATA_12_REG $to_write_userdata_12 s
usleep $I2C_ACTION_DELAY

read_data_12=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_USER_DATA_12_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 6 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $read_data_12 | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    read_userdata_12="${read_userdata_12}${array_pmbus_value[$i]}"
    if [[ "${VALUE_USER_DATA_12[$i]}" != "${array_pmbus_value[$i]}" ]]; then
        echo " # Fail ... USER_DATA_12 ( 0x${read_userdata_12} ) is not mapping to target ( 0x${userdata_12} )"
        Exit_NVM_Update
    fi
done


## Access VOUT_COMMAND [Rail#1]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_COMMAND_REG $VALUE_VOUT_COMMAND_RAIL1 w
usleep $I2C_ACTION_DELAY

vout_cmd_rail1=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_COMMAND_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_cmd_rail1" != "$VALUE_VOUT_COMMAND_RAIL1" ]; then
    echo " # Fail ... Vout_command setting ( $vout_cmd_rail1 ) is not mapping to target ( VALUE_VOUT_COMMAND_RAIL1 )"
    Exit_NVM_Update
fi

## Access VOUT_MARGIN_HIGH [Rail#1]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MARGIN_HIGH_REG $VALUE_VOUT_MARGIN_HIGH_RAIL1 w
usleep $I2C_ACTION_DELAY

vout_margin_high_rail1=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MARGIN_HIGH_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_margin_high_rail1" != "$VALUE_VOUT_MARGIN_HIGH_RAIL1" ]; then
    echo " # Fail ... Vout_margin_high setting ( $vout_margin_high_rail1 ) is not mapping to target ( VALUE_VOUT_MARGIN_HIGH_RAIL1 )"
    Exit_NVM_Update
fi

## Access VOUT_MARGIN_LOW [Rail#1]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MARGIN_LOW_REG $VALUE_VOUT_MARGIN_LOW_RAIL1 w
usleep $I2C_ACTION_DELAY

vout_margin_low_rail1=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MARGIN_LOW_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_margin_low_rail1" != "$VALUE_VOUT_MARGIN_LOW_RAIL1" ]; then
    echo " # Fail ... Vout_margin_low setting ( $vout_margin_low_rail1 ) is not mapping to target ( VALUE_VOUT_MARGIN_LOW_RAIL1 )"
    Exit_NVM_Update
fi

## Access VOUT_MIN [Rail#1]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MIN_REG $VALUE_VOUT_MIN_RAIL1 w
usleep $I2C_ACTION_DELAY

vout_min_rail1=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MIN_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_min_rail1" != "$VALUE_VOUT_MIN_RAIL1" ]; then
    echo " # Fail ... Vout_min setting ( $vout_min_rail1 ) is not mapping to target ( VALUE_VOUT_MIN_RAIL1 )"
    Exit_NVM_Update
fi

## Set to channel B (page 1)
Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_PAGE_REG 0x1

## Access VOUT_MAX [Rail#2]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MAX_REG $VALUE_VOUT_MAX_RAIL2 w
usleep $I2C_ACTION_DELAY

vout_max_rail2=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MAX_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_max_rail2" != "$VALUE_VOUT_MAX_RAIL2" ]; then
    echo " # Fail ... Vout_max setting ( $vout_max_rail2 ) is not mapping to target ( VALUE_VOUT_MAX_RAIL2 )"
    Exit_NVM_Update
fi

## Access VOUT_COMMAND [Rail#2]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_COMMAND_REG $VALUE_VOUT_COMMAND_RAIL2 w
usleep $I2C_ACTION_DELAY

vout_cmd_rail2=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_COMMAND_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_cmd_rail2" != "$VALUE_VOUT_COMMAND_RAIL2" ]; then
    echo " # Fail ... Vout_command setting ( $vout_cmd_rail2 ) is not mapping to target ( VALUE_VOUT_COMMAND_RAIL2 )"
    Exit_NVM_Update
fi

## Access VOUT_MARGIN_HIGH [Rail#2]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MARGIN_HIGH_REG $VALUE_VOUT_MARGIN_HIGH_RAIL2 w
usleep $I2C_ACTION_DELAY

vout_margin_high_rail2=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MARGIN_HIGH_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_margin_high_rail2" != "$VALUE_VOUT_MARGIN_HIGH_RAIL2" ]; then
    echo " # Fail ... Vout_margin_high setting ( $vout_margin_high_rail2 ) is not mapping to target ( VALUE_VOUT_MARGIN_HIGH_RAIL2 )"
    Exit_NVM_Update
fi

## Access VOUT_MARGIN_LOW [Rail#2]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MARGIN_LOW_REG $VALUE_VOUT_MARGIN_LOW_RAIL2 w
usleep $I2C_ACTION_DELAY

vout_margin_low_rail2=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MARGIN_LOW_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_margin_low_rail2" != "$VALUE_VOUT_MARGIN_LOW_RAIL2" ]; then
    echo " # Fail ... Vout_margin_low setting ( $vout_margin_low_rail2 ) is not mapping to target ( VALUE_VOUT_MARGIN_LOW_RAIL2 )"
    Exit_NVM_Update
fi

## Access VOUT_MIN [Rail#2]
i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MIN_REG $VALUE_VOUT_MIN_RAIL2 w
usleep $I2C_ACTION_DELAY

vout_min_rail2=$( { i2cget -y $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_VOUT_MIN_REG w ; } 2>&1 )
usleep $I2C_ACTION_DELAY
if [ "$vout_min_rail2" != "$VALUE_VOUT_MIN_RAIL2" ]; then
    echo " # Fail ... Vout_min setting ( $vout_min_rail2 ) is not mapping to target ( VALUE_VOUT_MIN_RAIL2 )"
    Exit_NVM_Update
fi

## Excute STORE_DEFAULT_ALL to set into NVM as new default.
Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $MPC_TPS536XX_STORE_DEFAULT_ALL_REG
usleep 1100000    # spec defined delay

## Check NVM checksum (4-byte)
data=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $MPC_TPS536XX_NVM_CHECKSUM_REG ; } 2>&1 )
usleep $I2C_ACTION_DELAY
for (( i = 0 , j = 2 ; i < 4 ; i++, j=i+2 ))
do
    array_pmbus_value[i]=$( { echo $data | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
done
nvm_checksum="${array_pmbus_value[0]}${array_pmbus_value[1]}${array_pmbus_value[2]}${array_pmbus_value[3]}"
if [ "$nvm_checksum" != "$TPS536XX_NVM_CHECKSUM" ]; then
    echo " # Fail ... NVM checksum ( 0x$nvm_checksum ) is not mapping to target ( 0x$TPS536XX_NVM_CHECKSUM )"
    Exit_NVM_Update
fi

Debug_And_Print_Value
echo " # TPS53679 NVM programming : Done"

Exit_NVM_Update
