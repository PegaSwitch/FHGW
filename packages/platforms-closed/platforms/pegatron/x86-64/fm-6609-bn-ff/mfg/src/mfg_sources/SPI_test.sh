#!/bin/bash

#######################################
# This script is to do SPI r/w test.
# $1 = test size
# $2 = test time
# $3 = gap time per round
# $4 = whether shown on console
# $5 = round number (file number)
#######################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

area_reserved="/tmp/reserveOrig"
area_write="/tmp/testWrite"
area_read="/tmp/testRead"
erase_size=0x1000        # test with 4Kb.  PS: SPI define erase block size=4096 in default.
mtd_access_delay=500000

if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
    chip_sel_reg=$DNV_CONTROL_CHIP_SEL_REG
    default_spi=$DNV_CONTROL_CHIP_SEL_DEFAULT
    backup_spi=$DNV_CONTROL_CHIP_SEL_GOLDEN
elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    chip_sel_reg=$BDX_CONTROL_CHIP_SEL_REG
    default_spi=$BDX_CONTROL_CHIP_SEL_DEFAULT
    backup_spi=$BDX_CONTROL_CHIP_SEL_GOLDEN
fi


function Log_Name_Check()    # $1 = round number ($5)
{
    test_log="$LOG_PATH_STORAGE/spi_rwTest.log"

    writeLog="$LOG_PATH_STORAGE/dd_write.log"
    if [ -f "$writeLog" ]; then
        rm $writeLog
    fi

    if [[ -z "$5" || "$5" == "0" ]]; then
        toAllLog="$LOG_PATH_STORAGE/peripheral_test.log"
    else
        toAllLog="$LOG_PATH_STORAGE/peripheral_test_$5.log"
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
        ipmi_value_toHex=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 2)))" ; } 2>&1 )    # orig value format is " XX" , so just get XX then transform as 0xXX format.
        echo $ipmi_value_toHex    # this line is to make return with value 0xXX
        return
    fi
}

function Read_Write_Test ()
{
    ## Prevent testing non-exist flash then cause weird output message.
    pretest_size=4096
    pre_read=$( { mtd_debug read /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size $area_reserved ; } 2>&1 )
    usleep $mtd_access_delay
    pre_erase=$( { mtd_debug erase /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size ; } 2>&1 )
    usleep $mtd_access_delay
    if [[ "$pre_erase" == *"Connection timed out"* ]]; then
        spi_not_exist=$TRUE
        Exit_Test
    else
        pre_restore=$( { mtd_debug write /dev/mtd0 $SPI_PDR_BASE_ADDRESS $pretest_size $area_reserved ; } 2>&1 )
        usleep $mtd_access_delay
    fi

    ## Prepare a test file.
    if [[ "$outputconsole" == "yes" ]]; then
        echo "  Create a file with $test_size size ..."
    fi

    dd if=$STORAGE_TEST_INPUT_FILE of=/dev/shm/tmptest bs=1c count=$test_size &>> $writeLog      # 1c = 1-byte
    md5_orig=$(md5sum /dev/shm/tmptest | awk '{print $1}' )
    #printf "  md5sum of origin File = %s \n" $md5_orig | tee -a $test_log
    cat /dev/shm/tmptest | od -h >> $test_log

    dd if=/dev/shm/tmptest of=$area_write &>> $writeLog      # 1c = 1-byte
    case "$?" in
        0) echo "  Create a $test_size bytes of file : Done." &>> $test_log
            ;;
        *) echo "  dd error while create file. " | tee -a $test_log
            ;;
    esac

    md5_w=$(md5sum $area_write | awk '{print $1}' )
    if [[ "$outputconsole" == "yes" ]]; then
        printf "  md5sum of write File = %s \n" $md5_w | tee -a $test_log
    else
        printf "  md5sum of write File = %s \n" $md5_w &>> $test_log
    fi
    cat $area_write | od -h >> $test_log

    mtd_debug read /dev/mtd0 $SPI_PDR_BASE_ADDRESS $erase_size $area_reserved &>> $test_log
    sleep 1
    # cat $area_reserved

    ## erase SPI PDR region first, so as to let write-in value stored right.
    mtd_debug erase /dev/mtd0 $SPI_PDR_BASE_ADDRESS $erase_size &>> $test_log
    sleep 1

    ## To write from dram to storage
    if [[ "$outputconsole" == "yes" ]]; then
        echo "  Start to write SPI ..." | tee -a $test_log
    else
        echo "  Start to write SPI ..." &>> $test_log
    fi
    mtd_debug write /dev/mtd0 $SPI_PDR_BASE_ADDRESS $test_size $area_write &>> $test_log

    sleep 2

    ## To write from storage back to dram
    if [[ "$outputconsole" == "yes" ]]; then
        echo "  Start to read SPI ..." | tee -a $test_log
    else
        echo "  Start to read SPI ..." &>> $test_log
    fi
    mtd_debug read /dev/mtd0 $SPI_PDR_BASE_ADDRESS $test_size $area_read &>> $test_log

    cat $area_read | od -h >> $test_log

    ## Get md5 checksum of read out data
    md5_r=$(md5sum $area_read | awk '{print $1}' )
    if [[ "$outputconsole" == "yes" ]]; then
        printf "  md5sum of readback file = %s \n" $md5_r | tee -a $test_log
    else
        printf "  md5sum of readback file = %s \n" $md5_r &>> $test_log
    fi

    rm $area_read && sync
    rm $area_write && sync
    if [[ "$outputconsole" == "yes" ]]; then
        echo " " | tee -a $test_log
    else
        echo " " &>> $test_log
    fi

    ## Erase SPI PDR region.
    mtd_debug erase /dev/mtd0 $SPI_PDR_BASE_ADDRESS $erase_size &>> $test_log
    sleep 1

    ## Restore data
    mtd_debug write /dev/mtd0 $SPI_PDR_BASE_ADDRESS $test_size $area_reserved &>> $test_log
    echo "  Retore PDR default value done."

    ## Compare file size and md5 equal or not
    if [ -z "$md5_r" -o -z "$md5_orig" ];then
        if [[ "$outputconsole" == "yes" ]]; then
            echo "  ====> SPI Test FAIL" | tee -a $test_log
        else
            echo "  ====> SPI Test FAIL" &>> $test_log $toAllLog
        fi
    elif [ "$md5_orig" == "$md5_r" ];then
        if [[ "$outputconsole" == "yes" ]]; then
            echo "  ====> SPI Test PASS" | tee -a $test_log
        else
            echo "  ====> SPI Test PASS" &>> $test_log $toAllLog
        fi
        rm $writeLog
    else
        if [[ "$outputconsole" == "yes" ]]; then
            echo "  ====> SPI Test FAIL" | tee -a $test_log
            printf "\n End : " |& tee -a $test_log
            timestamp |& tee -a $test_log
        else
            echo "  ====> SPI Test FAIL" &>> $test_log $toAllLog
            printf "\n End : " &>> $test_log
            timestamp &>> $test_log
        fi
        echo "----------------------------------" >> $test_log
        #exit 1
    fi
}

function Mutex_Check_And_Create()
{
    ## check whether mutex key create by others process, if exist, wait until this procedure can create then keep go test.
    while [ -f $I2C_MUTEX_NODE ]
    do
        echo " !!! Wait for I2C bus free !!!" >> $test_log
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

function Exit_Test ()
{
    if [[ "$outputconsole" == "yes" ]]; then
        echo "  ====> Skip test due to SPI not exist." | tee -a $test_log
    else
        echo "  ====> Skip test due to SPI not exist." &>> $test_log $toAllLog
    fi

    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $chip_sel_reg $sel_ori
    fi

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi
    exit 1
}

### Main ###

if [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
    echo " Rangeley NOT support SPI r/w test !!!"
    exit 1
fi

if [[ ! -z "$1" ]]; then
    if (( $1 > 1024 )); then   ## DON't over 64Kb ( because size of SPI PRD region is 0x10000. )
        echo " Oversize !!! Please less than 4 Kb"
        exit 1
    else
        test_size=$1
    fi
else
    test_size=16    ## 16-byte
fi

## caculate execution time
if [[ -z "$2" ]]; then
    ## only execute once, so set 2 sec for temp (fun)
    endtime=$(($(date +%s) + 2 ))
else
    if (( $2 == 0 )); then
        endtime=$(($(date +%s) + 2592000 ))    # 30 days = 2592000 sec
    else
        endtime=$(($(date +%s) + $2 ))
    fi
fi

## whether output on console
if [[ -z "$4" || "$4" == "yes" ]]; then
    outputconsole="yes"
else
    outputconsole="no"
fi

Log_Name_Check $5

## Main start
if [[ "$outputconsole" == "yes" ]]; then
    printf " Start : " |& tee -a $test_log
    timestamp |& tee -a $test_log
    echo ""
else
    printf " Start : " &>> $test_log
    timestamp &>> $test_log
    printf " ---- SPI test Start ----\n" &>> $toAllLog
fi

round_index=1
while (( $(date +%s) < $endtime )) ;
do
    printf " ---- Round %d ----\n" $round_index &>> $test_log
    timestamp &>> $test_log

    Mutex_Check_And_Create
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
    fi

    ## check which was used in this moment, and then get md5sum
    sel_ori=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $chip_sel_reg ; } 2>&1 )
    chip_sel=$(( $sel_ori & 0x1 ))    ## lase bit - CPU-Boot_Sel of BDX_BMC version.
    chip_sel_hex=$( { echo "0x"${chip_sel} ; } 2>&1 )
    if (( $chip_sel_hex == $default_spi ));then
        if [[ "$outputconsole" == "yes" ]]; then
            echo " test Main SPI ..." | tee -a $test_log
        else
            echo " test Main SPI ..." &>> $test_log
        fi
        invert=$backup_spi
        invert_spi="Backup"
    else
        if [[ "$outputconsole" == "yes" ]]; then
            echo " test Backup SPI ..." | tee -a $test_log
        else
            echo " test Backup SPI ..." &>> $test_log
        fi
        invert=$default_spi
        invert_spi="Main"
    fi

    Read_Write_Test

    if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        new_cs_pin=$(( ( $sel_ori & 0xfe ) | $invert ))
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $chip_sel_reg $new_cs_pin
    elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        ## switch to the other SPI.
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $chip_sel_reg $invert

    fi
    usleep $I2C_ACTION_DELAY
    chipSel=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $chip_sel_reg ; } 2>&1 )
    usleep $I2C_ACTION_DELAY
    check_cp_pin=$(( $chipSel & 0x1 ))
    check_cp_pin_hex=$( { echo "0x"${check_cp_pin} ; } 2>&1 )

    if (( $check_cp_pin_hex != $invert )); then
        if [[ "$outputconsole" == "yes" ]]; then
            echo ""
            echo " Swtich to $invert_spi SPI Fail , skip check checksum of $invert_spi SPI ..." | tee -a $test_log
        else
            echo " Swtich to $invert_spi SPI Fail , skip check checksum of $invert_spi SPI ..." &>> $test_log
        fi

        Mutex_Clean
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
        fi
        exit 1
    else
        if [[ "$outputconsole" == "yes" ]]; then
            echo " Swtich to $invert_spi SPI ..."
            echo ""
        fi
        if (( $invert == $default_spi ));then
            if [[ "$outputconsole" == "yes" ]]; then
                echo " test Main SPI ..." | tee -a $test_log
            else
                echo " test Main SPI ..." &>> $test_log
            fi
        else
            if [[ "$outputconsole" == "yes" ]]; then
                echo " test Backup SPI ..." | tee -a $test_log
            else
                echo " test Backup SPI ..." &>> $test_log
            fi
        fi
    fi

    Read_Write_Test

    ## switch back to origin SPI
    Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $chip_sel_reg $sel_ori

    Mutex_Clean
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
    fi


    ## gap round delay time
    if [[ -z "$3" ]]; then
        sleep 3
    else
        sleep $3
    fi

    round_index=$(( $round_index +1 ))
    printf " \n" &>> $test_log
done

if [[ "$outputconsole" == "yes" ]]; then
    printf "\n End : " |& tee -a $test_log
    timestamp |& tee -a $test_log
else
    printf "\n End : " &>> $test_log
    timestamp &>> $test_log
fi
echo "----------------------------------" >> $test_log
