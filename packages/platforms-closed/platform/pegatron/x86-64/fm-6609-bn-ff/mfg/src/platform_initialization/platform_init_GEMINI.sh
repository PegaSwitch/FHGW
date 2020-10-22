## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

function I2C_Device_Detect()
{
    i2c_bus=$1
    i2c_device=$2

    ## Check Device Exist
    result=$( { i2cdetect -y $i2c_bus; } 2>&1 )
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

function Modules_Transmitter_Enable ()
{
    ## 20200916 Add I/O expander (TCA6424A) on MB v3.00 control power of each ports.
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_5
    I2C_Device_Detect $I2C_BUS $IO_EXPANDER_1
    if (( $device_exist_check == $SUCCESS )); then
        ## Set 'Configuration Register' (reg 12 ~ 14) as 'output' direction (value = 0).
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_1 0x0c 0x00
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_1 0x0d 0x00
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_1 0x0e 0x00
        ## Set 'Output port Register' (reg 4 ~ 6) as high
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_1 0x04 0xff
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_1 0x05 0xff
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_1 0x06 0xff
    fi
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_6
    I2C_Device_Detect $I2C_BUS $IO_EXPANDER_2
    if (( $device_exist_check == $SUCCESS )); then
        ## Set 'Configuration Register' (reg 12 ~ 14) as 'output' direction (value = 0).
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_2 0x0c 0x00
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_2 0x0d 0x00
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_2 0x0e 0x00
        ## Set 'Output port Register' (reg 4 ~ 6) as high
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_2 0x04 0xff
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_2 0x05 0xff
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_2 0x06 0xff
    fi
    ##                            PCA9534A on MB v3.00
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_7
    I2C_Device_Detect $I2C_BUS $IO_EXPANDER_3
    if (( $device_exist_check == $SUCCESS )); then
        ## Set 'Configuration Register' (reg 3) as 'output' direction (value = 0).
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_3 0x03 0x00
        ## Set 'Output port Register' (reg 1) as high
        Write_I2C_Device_Node $I2C_BUS $IO_EXPANDER_3 0x01 0xff
    fi
    ## 20200916 Add End.

    ## SFP 1 ~ 12
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_1
    for (( index = $CPLD_B_MSRR1_REG ; index <= 0x0A ; index++ ))
    do
        hexVal=$( { echo obase=16"; $index" | bc ; } 2>&1 )
        index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
        Write_I2C_Device_Node $I2C_BUS $CPLD_B_ADDR $index_hex 0x00
    done

    ## Enable SLED (MCR [3], default value = 0x02)
    Write_I2C_Device_Node $I2C_BUS $CPLD_B_ADDR 0x01 0x0a

    ## SFP 13 ~ 40
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
    for (( index = $CPLD_A_MSRR_REG ; index <= 0x16 ; index++ ))
    do
        hexVal=$( { echo obase=16"; $index" | bc ; } 2>&1 )
        index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
        Write_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR $index_hex 0x00
    done

    ## Enable SLED (LEDCR2 [2], default value = 0x02)
    Write_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR 0x02 0x0a

    ## SFP 41 ~ 48
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_2
    for (( index = $CPLD_C_MSRR1_REG ; index <= 0x0C ; index++ ))
    do
        hexVal=$( { echo obase=16"; $index" | bc ; } 2>&1 )
        index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
        Write_I2C_Device_Node $I2C_BUS $CPLD_C_ADDR $index_hex 0x00
    done

    ## QSFP 49 ~ 56
    for (( index = $QSFP_QRSTR_REG ; index <= 0x11 ; index++ ))
    do
        hexVal=$( { echo obase=16"; $index" | bc ; } 2>&1 )
        index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
        Write_I2C_Device_Node $I2C_BUS $CPLD_C_ADDR $index_hex 0x55
    done

    ## Enable SLED (MCR [3], default value = 0x02)
    Write_I2C_Device_Node $I2C_BUS $CPLD_C_ADDR 0x02 0x0a

    ## Restore MUX channel to default
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG 0x0
}

function Mutex_Check_And_Create()
{
    ## check whether mutex key create by others process, if exist, wait until this procedure can create then keep go test.
    while [ -f $I2C_MUTEX_NODE ]
    do
        #echo " !!! Wait for I2C bus free !!!" |& tee -a $testLog
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

echo " [ GEMINI ] Platform default setting"

## For support OOB console action
telnetd

## enable 2 10G-KR ports (!!! Temporary mark off for EDVT traffic test )
# ifconfig eth1 up
# ifconfig eth2 up

## do modules' Tx enable.
Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

Modules_Transmitter_Enable

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi

## do each team/purpose request testing.
bash $MFG_WORK_DIR/diag_test

