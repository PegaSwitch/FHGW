#!/bin/bash

#####################################################################
# This script is to do storage test.
# $1 = user input path ;
# $2 = test size ;
# $3 = console output or not ;
# $4 = cycle log named number
# $5 = round log named number
#####################################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

storage_write="$1/ddTest_storageWriteIn"


function Parameter_Init() # $1: testDevice, $2: testCycle, $3: testRound
{
    # check log file
    if [[ -z "$2" ]]; then
        toAllLog="$LOG_PATH_STORAGE/peripheral_test.log"
    else
        if [ ! -z "$3" ]; then
            toAllLog="$LOG_PATH_STORAGE/peripheral_test_$2_$3.log"
        else
            toAllLog="$LOG_PATH_STORAGE/peripheral_test_$2.log"
        fi
    fi

    if [[ "$1" = *"USB"* ]];then
        test_storage_type="USB"
        if [[ -z "$2" ]]; then
            test_log="$LOG_PATH_STORAGE/usb_test.log"
        else
            if [ ! -z "$3" ]; then
                test_log="$LOG_PATH_STORAGE/usb_test_$2_$3.log"
            else
                test_log="$LOG_PATH_STORAGE/usb_test_$2.log"
            fi
        fi
        fromMem="/dev/shm/createFile_usb.txt"
        toMem="/dev/shm/readBackFile_usb.txt"
        writeLog="$LOG_PATH_STORAGE/dd_write_usb.log"
        readLog="$LOG_PATH_STORAGE/dd_read_usb.log"

    elif [[ "$1" = *"eMMC"* ]];then
        test_storage_type="eMMC"
        if [[ -z "$2" ]]; then
            test_log="$LOG_PATH_STORAGE/emmc_test.log"
        else
            if [ ! -z "$3" ]; then
                test_log="$LOG_PATH_STORAGE/emmc_test_$2_$3.log"
            else
                test_log="$LOG_PATH_STORAGE/emmc_test_$2.log"
            fi
        fi
        fromMem="/dev/shm/createFile_emmc.txt"
        toMem="/dev/shm/readBackFile_emmc.txt"
        writeLog="$LOG_PATH_STORAGE/dd_write_emmc.log"
        readLog="$LOG_PATH_STORAGE/dd_read_emmc.log"

    elif [[ "$1" = *"SSD"* ]];then
        test_storage_type="SSD"
        if [[ -z "$2" ]]; then
            test_log="$LOG_PATH_STORAGE/ssd_test.log"
        else
            if [ ! -z "$3" ]; then
                test_log="$LOG_PATH_STORAGE/ssd_test_$2_$3.log"
            else
                test_log="$LOG_PATH_STORAGE/ssd_test_$2.log"
            fi
        fi
        fromMem="/dev/shm/createFile_ssd.txt"
        toMem="/dev/shm/readBackFile_ssd.txt"
        writeLog="$LOG_PATH_STORAGE/dd_write_ssd.log"
        readLog="$LOG_PATH_STORAGE/dd_read_ssd.log"
    else
        echo " Please assign test folder path."
        exit 0
    fi
}

if [[ ! -z "$5" ]]; then
    Parameter_Init $1 $4 $5
else
    Parameter_Init $1 $4
fi

if [[ -z "$3" || "$3" == "yes" ]]; then
    outputconsole="yes"
else
    outputconsole="no"
fi

if [[ "$outputconsole" == "yes" ]]; then
    printf " ---- %s test Start ----\n" $test_storage_type
    printf " Start : " |& tee -a $test_log
    timestamp |& tee -a $test_log
else
    printf " Start : " &>> $test_log
    timestamp &>> $test_log
fi

## Prepare a file in ram/disk, depends on where your rootfs stand.
if [[ "$outputconsole" == "yes" ]]; then
    echo "  Create a file size in ram ..."
    dd if=$STORAGE_TEST_INPUT_FILE of=$fromMem bs=1M count=$2 |& tee -a $writeLog ; sync ; sleep 2
    case "$?" in
        0) echo "  Create a size of file in RAM partition done."
            if [ -f $writeLog ]; then
                rm $writeLog && sync
            fi
            ;;
        *) echo "  dd error while create file in dram " | tee -a $test_log
            ;;
    esac
else
    dd if=$STORAGE_TEST_INPUT_FILE of=$fromMem bs=1M count=$2 &>> $writeLog ; sync ; sleep 2
    case "$?" in
        0)  if [ -f $writeLog ]; then
                rm $writeLog && sync
            fi
            ;;
        *)  echo "  dd error while create file in dram " &>> $test_log
            ;;
    esac
fi

if [ ! -f $fromMem ]; then
    md5_orig=0
else
    md5_orig=$(md5sum $fromMem | awk '{print $1}' )
fi
if [[ "$outputconsole" == "yes" ]]; then
    printf "  md5sum of origin ram File for %s = %s \n" $test_storage_type $md5_orig | tee -a $test_log
else
    printf "  md5sum of origin ram File for %s = %s \n" $test_storage_type $md5_orig &>> $test_log
fi

## Delete cache first, to get right read speed, it needs sudo privilege.
/sbin/sysctl -w vm.drop_caches=3 > /tmp/storage_test_tmp.txt

## To write from dram to storage 
if [[ "$outputconsole" == "yes" ]]; then
    echo "  Start to write ..."
    dd if=$fromMem of=$storage_write |& tee -a $test_log ; sync ; sleep 2
    case "$?" in
        0) printf "  The %s writing test done.\n" $test_storage_type
            ## To get write in file bytes (skip because DUT no support showing transmit bytes)
            # writeByte=$(cat $writeLog | grep "bytes" | sed -n "1p" | cut -d " " -f 1 )
            # echo "  Write Byte = " $writeByte &>>  $test_log
            # rm $writeLog && sync

            ## Get md5 checksum of write in data
            if [ ! -f $storage_write ]; then
                md5_w=0
            else
                md5_w=$(md5sum $storage_write | awk '{print $1}' )
            fi
            printf "  md5sum of %s write = %s \n" $test_storage_type $md5_w | tee -a $test_log
            ;;
        *) printf "  dd error while dram to %s \n" $test_storage_type | tee -a $test_log
            ;;
    esac
else
    dd if=$fromMem of=$storage_write &>> $test_log ; sync ; sleep 2
    case "$?" in
        0)  if [ ! -f $storage_write ]; then
                md5_w=0
            else
                md5_w=$(md5sum $storage_write | awk '{print $1}' )
            fi
            printf "  md5sum of %s write = %s \n" $test_storage_type $md5_w &>> $test_log
            ;;
        *) printf "  dd error while dram to %s \n" $test_storage_type &>> $test_log
            ;;
    esac
fi

if [ -f $fromMem ]; then
    rm $fromMem && sync    ## remove orig file in dram to resolve dram space lack problem.
fi

## To write from storage back to dram
if [[ "$outputconsole" == "yes" ]]; then
    echo "  Start to read ..."
    dd if=$storage_write of=$toMem |& tee -a $test_log ; sync ; sleep 2
    case "$?" in
        0) printf "  The %s reading test done.\n" $test_storage_type 
            ## To get read out file bytes (skip because DUT no support showing transmit bytes)
            # readByte=$(cat $readLog | grep "bytes" | cut -d " " -f 1 )
            # echo "  Read Byte = " $readByte &>> $test_log
            # rm $readLog && sync

            ## Get md5 checksum of read out data
            if [ ! -f $toMem ]; then
                md5_r=0
            else
                md5_r=$(md5sum $toMem | awk '{print $1}' )
            fi
            printf "  md5sum of %s read = %s \n" $test_storage_type $md5_r | tee -a $test_log
            ;;
        *) printf "  dd error while %s to dram\n" $test_storage_type | tee -a $test_log
            ;;
    esac
else
    dd if=$storage_write of=$toMem &>> $test_log ; sync ; sleep 2
    case "$?" in
        0)  if [ ! -f $toMem ]; then
                md5_r=0
            else
                md5_r=$(md5sum $toMem | awk '{print $1}' )
            fi
            printf "  md5sum of %s read = %s \n" $test_storage_type $md5_r &>> $test_log
            ;;
        *) printf "  dd error while %s to dram\n" $test_storage_type &>> $test_log
            ;;
    esac
fi

if [ -f $toMem ]; then
    rm $toMem && sync
fi
if [ -d "$1" ]; then
    rm -rf $1 && sync
fi
echo " " | tee -a $test_log $toAllLog

## Compare file size and md5 equal or not
if [[ "$outputconsole" == "yes" ]]; then
    if [ -z "$md5_w" -o -z "$md5_r" -o -z "$md5_orig" ];then
        echo "  ====> $test_storage_type Test FAIL" | tee -a $test_log $toAllLog
    elif [ "$md5_w" == "$md5_r" -a "$md5_orig" == "$md5_r" ];then
        echo "  ====> $test_storage_type Test PASS" | tee -a $test_log $toAllLog
    else
        echo "  ====> $test_storage_type Test FAIL" | tee -a $test_log $toAllLog
    fi

    printf "\n End : " |& tee -a $test_log
    timestamp |& tee -a $test_log
    echo "----------------------------------" >> $test_log

    printf " ---- %s test End ----\n\n" $test_storage_type
else
    if [ -z "$md5_w" -o -z "$md5_r" -o -z "$md5_orig" ];then
        echo "  ====> $test_storage_type Test FAIL" &>> $test_log
        echo "  ====> $test_storage_type Test FAIL" &>> $toAllLog
    elif [ "$md5_w" == "$md5_r" -a "$md5_orig" == "$md5_r" ];then
        echo "  ====> $test_storage_type Test PASS" &>> $test_log
        echo "  ====> $test_storage_type Test PASS" &>> $toAllLog
    else
        echo "  ====> $test_storage_type Test FAIL" &>> $test_log
        echo "  ====> $test_storage_type Test FAIL" &>> $toAllLog
    fi
    printf "\n End : " &>> $test_log
    timestamp &>> $test_log
    echo "----------------------------------" >> $test_log

fi
