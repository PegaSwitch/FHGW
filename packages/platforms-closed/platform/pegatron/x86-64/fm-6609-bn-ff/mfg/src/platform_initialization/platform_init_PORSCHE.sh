## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

function Modules_Transmitter_Enable ()
{
    ## SFP 1 ~ 12
    i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_1
    usleep $I2C_ACTION_DELAY
    for (( index = $CPLD_B_MSRR_REG ; index <= 0x0A ; index++ ))
    do
        hexVal=$( { echo obase=16"; $index" | bc ; } 2>&1 )
        index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
        i2cset -y $I2C_BUS $CPLD_B_ADDR $index_hex 0x00
        usleep $I2C_ACTION_DELAY
    done

    ## Enable SLED (SYNCCR)
    i2cset -y $I2C_BUS $CPLD_B_ADDR $CPLD_MCR_REG $CPLD_MCR_VALUE_NORMAL

    ## SFP 13 ~ 36
    i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
    usleep $I2C_ACTION_DELAY
    for (( index = $CPLD_A_MSRR_REG ; index <= 0x13 ; index++ ))
    do
        hexVal=$( { echo obase=16"; $index" | bc ; } 2>&1 )
        index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
        i2cset -y $I2C_BUS $CPLD_A_ADDR $index_hex 0x00
        usleep $I2C_ACTION_DELAY
    done

    ## SFP 37 ~ 48
    i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_2
    usleep $I2C_ACTION_DELAY
    for (( index = $CPLD_C_MSRR1_REG ; index <= 0x0E ; index++ ))
    do
        hexVal=$( { echo obase=16"; $index" | bc ; } 2>&1 )
        index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
        i2cset -y $I2C_BUS $CPLD_C_ADDR $index_hex 0x00
        usleep $I2C_ACTION_DELAY
    done

    ## QSFP 49 ~ 54
    for (( index = $QSFP_QRSTR_REG ; index <= 0x11 ; index++ ))
    do
        hexVal=$( { echo obase=16"; $index" | bc ; } 2>&1 )
        index_hex=$( { echo "0x"$hexVal ; } 2>&1 )
        i2cset -y $I2C_BUS $CPLD_C_ADDR $index_hex 0x55
        usleep $I2C_ACTION_DELAY
    done

    ## Restore MUX channel to default
    i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG 0x0
    usleep $I2C_ACTION_DELAY
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

echo " [ PORSCHE2 ] Platform default setting"

## enable OOB ports
ifconfig $ETHTOOL_NAME 192.168.1.254 netmask 255.255.255.0 up

## do modules' Tx enable.
Mutex_Check_And_Create
Modules_Transmitter_Enable
Mutex_Clean

## Insert SDK kernel module
checknode=$( { lsmod | grep "nps_dev" ; } 2>&1 )
if [[ -z "$checknode" ]]; then
    insmod $MFG_WORK_DIR/sdk_configuration/nps_dev.ko
fi

## Prevent restore to affect burn-in mode.
checkflag=$( { cat $DIAG_CONF_FILE_NAME | grep "Burn-In Set" ; } 2>&1 )
if [[ "$checkflag" == *"on"* ]];then
    burnin=on
else
    burnin=off
fi
## Resume NPS SDK default cfg.dsh
if [[ -f "$MFG_WORK_DIR/cfg_backupOrig.dsh" && "$burnin" == "off" ]]; then
    # echo " [debug] need to resume original cfg.dsh first"
    cp $MFG_WORK_DIR/cfg_backupOrig.dsh $MFG_WORK_DIR/cfg.dsh
    sync
    sleep 1
    rm $MFG_WORK_DIR/cfg_backupOrig.dsh
fi

## do each team/purpose request testing.
bash $MFG_WORK_DIR/diag_test

## echo "[MFG] execute nephos SDK"
# bash $MFG_WORK_DIR/sdk_ref

#sh $MFG_SOURCE_DIR/fw_regression_test.sh

