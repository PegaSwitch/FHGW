#!/bin/bash

###################################################
# This script is to do storage test.
# $1 = user input path
# $2 test size
# $3 test round , for log naming
###################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

storage_write="$1/ddTest_storageWriteIn"
fromMem="/dev/shm/createFile.txt"
toMem="/dev/shm/readBackFile.txt"

function Parameter_Init() # $1: testDevice, $2: testRound
{
    # check log file
    if [[ -z "$2" ]]; then
        toAllLog="$LOG_PATH_STORAGE/peripheral_test.log"
    else
        toAllLog="$LOG_PATH_STORAGE/peripheral_test_$2.log"
    fi

    writeLog="$LOG_PATH_STORAGE/dd_write.log"
    readLog="$LOG_PATH_STORAGE/dd_read.log"
    if [ -f "$writeLog" ]; then
        rm $writeLog
    fi
    if [ -f "$readLog" ]; then
        rm $readLog
    fi

    if [[ "$1" = *"USB"* ]];then
        test_storage_type="USB"
        if [[ -z "$2" ]]; then
            test_log="$LOG_PATH_STORAGE/usb_test.log"
        else
            test_log="$LOG_PATH_STORAGE/usb_test_$2.log"
        fi
    elif [[ "$1" = *"eMMC"* ]];then
        test_storage_type="eMMC"
        if [[ -z "$2" ]]; then
            test_log="$LOG_PATH_STORAGE/emmc_test.log"
        else
            test_log="$LOG_PATH_STORAGE/emmc_test_$2.log"
        fi
    elif [[ "$1" = *"SSD"* ]];then
        test_storage_type="SSD"
        if [[ -z "$2" ]]; then
            test_log="$LOG_PATH_STORAGE/ssd_test.log"
        else
            test_log="$LOG_PATH_STORAGE/ssd_test_$2.log"
        fi
    else
        echo " Please assign test folder path."
        exit 0
    fi
}

Parameter_Init $1 $3

printf " ---- %s test Start ----\n" $test_storage_type |& tee -a $toAllLog
printf " Start : " |& tee -a $test_log
timestamp |& tee -a $test_log

## Prepare a file in ram/disk, depends on where your rootfs stand.
echo "  Create a file size in ram ..."
dd if=$STORAGE_TEST_INPUT_FILE of=$fromMem bs=1M count=$2 |& tee -a $writeLog
case "$?" in
    0) echo "  Create a size of file in RAM partition done."
        ;;
    *) echo "  dd error while create file in dram " | tee -a $test_log $toAllLog
        ;;
esac

md5_orig=$(md5sum $fromMem | awk '{print $1}' )
printf "  md5sum of origin ram File for %s = %s \n" $test_storage_type $md5_orig | tee -a $test_log $toAllLog

## Delete cache first, to get right read speed, it needs sudo privilege.
/sbin/sysctl -w vm.drop_caches=3

## To write from dram to storage 
echo "  Start to write ..."
dd if=$fromMem of=$storage_write |& tee -a $test_log ; sync    ## $writeLog
case "$?" in
    0) printf "  The %s writing test done.\n" $test_storage_type
        ## To get write in file bytes (skip because DUT no support showing transmit bytes)
        # writeByte=$(cat $writeLog | grep "bytes" | sed -n "1p" | cut -d " " -f 1 )
        # echo "  Write Byte = " $writeByte &>>  $test_log
        # rm $writeLog && sync

        ## Get md5 checksum of write in data
        md5_w=$(md5sum $storage_write | awk '{print $1}' )
        printf "  md5sum of %s write = %s \n" $test_storage_type $md5_w | tee -a $test_log $toAllLog
        ;;
    *) printf "  dd error while dram to %s \n" $test_storage_type | tee -a $test_log $toAllLog
        ;;
esac


## To write from storage back to dram
echo "  Start to read ..."
dd if=$storage_write of=$toMem |& tee -a $test_log      ## $readLog
case "$?" in
    0) printf "  The %s reading test done.\n" $test_storage_type 
        ## To get read out file bytes (skip because DUT no support showing transmit bytes)
        # readByte=$(cat $readLog | grep "bytes" | cut -d " " -f 1 )
        # echo "  Read Byte = " $readByte &>> $test_log
        # rm $readLog && sync

        ## Get md5 checksum of read out data
        md5_r=$(md5sum $toMem | awk '{print $1}' )
        printf "  md5sum of %s read = %s \n" $test_storage_type $md5_r | tee -a $test_log $toAllLog
        ;;
    *) printf "  dd error while %s to dram\n" $test_storage_type | tee -a $test_log $toAllLog
        ;;
esac

rm $toMem && sync
rm $fromMem && sync
rm $storage_write* && sync
echo " " | tee -a $test_log $toAllLog

## Compare file size and md5 equal or not
if [ -z "$md5_w" -o -z "$md5_r" -o -z "$md5_orig" ];then
    echo "  ====> $test_storage_type Test FAIL" | tee -a $test_log $toAllLog
elif [ "$md5_w" == "$md5_r" -a "$md5_orig" == "$md5_r" ];then
    echo "  ====> $test_storage_type Test PASS" | tee -a $test_log $toAllLog
else
    echo "  ====> $test_storage_type Test FAIL" | tee -a $test_log $toAllLog
    printf "\n End : " |& tee -a $test_log
    timestamp |& tee -a $test_log
    echo "----------------------------------" >> $test_log
    exit 1
fi

printf "\n End : " |& tee -a $test_log
timestamp |& tee -a $test_log
echo "----------------------------------" >> $test_log

if [[ "$1" = *"USB"* ]];then
    checkExist=$( mount | grep "$1" )
    if [[ ! -z $checkExist ]]; then
        umount $1
        rm -rf $1
    fi
fi

printf " ---- %s test End ----\n\n" $test_storage_type |& tee -a $toAllLog
