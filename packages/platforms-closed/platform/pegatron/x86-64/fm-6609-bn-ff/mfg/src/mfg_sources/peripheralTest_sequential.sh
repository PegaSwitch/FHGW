#!/bin/bash

############################################################################
# This script is to start peripheral test, include dram,storage(eMMC/USB/SSD).
# Develope by Jenny 20180601
# $1 is user decide the test size
# $2 is test round number, add on 20180910
# $3 is for single test item request.
############################################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh


function Log_Name_Check() # $1: test_round
{
    if [ -z "$1" ]; then
        toAllLog="$LOG_PATH_STORAGE/peripheral_test.log"
    else
        toAllLog="$LOG_PATH_STORAGE/peripheral_test_$1.log";
    fi
    if [ -f "$toAllLog" ]; then rm "$toAllLog"; fi
}

function Check_EMMC_RW_Partition_And_Test ()
{
    if (( $emmc_not_exist == $TRUE ));then
        printf " ---- eMMC test Start ----\n\n" |& tee -a $toAllLog
        echo " eMMC is not inserted." |& tee -a $toAllLog
        # printf "  ====> eMMC Test FAIL\n\n" |& tee -a $toAllLog
        printf " ---- eMMC test End ----\n" |& tee -a $toAllLog
    else
        ## Check if disk is mounted already (maybe this script had run before), or mount up.
        check_mount_status=$( { mount | grep "$FOLDER_PATH_EMMC" ; } 2>&1 )
        if [[ ! -z "$check_mount_status" ]]; then
            echo " eMMC is already mounted."
        else
            if [ ! -d "$FOLDER_PATH_EMMC" ]; then    ## if folder already exist, skip create new folders.
                mkdir $FOLDER_PATH_EMMC
            fi

            ## mount r/w test partition.
            emmc_lastpart=$( ls -al /dev/disk/by-id/ | grep "$EMMC_LABEL" | sed -n '$p' | cut -d '/' -f 3 )
            emmc_disk=$( echo $emmc_lastpart | cut -c1-3 )
            if (( $ONIE_ACCESS_WAY == 0 )); then
                mount /dev/$emmc_lastpart $FOLDER_PATH_EMMC    # define test area(/dev/sd*4)
            else
                if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
                    ## ONIE layout -- sd*2 for MFG rootfs, sd*3 for store logs and for r/w test.
                    log_part_amount=$( blkid | grep "$ONIE_PARTITION_LOG_NAME" | awk '{print $1}' | cut -d ':' -f 1 | cut -d '/' -f 3 | wc -l )
                    if (( $log_part_amount > 1 )); then
                        emmc_mfg_part=$( ls -al /dev/disk/by-id/ | grep "$EMMC_LABEL" | sed -n '4p' | cut -d '/' -f 3 )
                    else
                        emmc_mfg_part=$( blkid | grep "$ONIE_PARTITION_LOG_NAME" | awk '{print $1}' | cut -d ':' -f 1 | cut -d '/' -f 3 )
                    fi
                    onie_loc=$( echo $emmc_mfg_part | cut -c1-3 )

                    if [[ "$emmc_disk" != "$onie_loc" ]]; then    ## onie format in another disk (SSD), eMMC is only for test.
                        mount /dev/$emmc_lastpart $FOLDER_PATH_EMMC
                    else
                        mount /dev/$emmc_mfg_part $FOLDER_PATH_EMMC
                    fi
                else # DNV
                    mount /dev/$emmc_lastpart $FOLDER_PATH_EMMC
                fi
            fi
        fi

        ## prepare test area(folder) and show out the partition.
        if [ ! -d "$FOLDER_PATH_EMMC_TEST_AREA" ]; then
            mkdir $FOLDER_PATH_EMMC_TEST_AREA
        fi
        check_mount_status=$( { mount | grep "$FOLDER_PATH_EMMC" | awk '{print $1}' | cut -d ':' -f 1 | cut -d '/' -f 3 ; } 2>&1 )
        printf ' eMMC test partition is %s\n' $check_mount_status

        ## fork a thread to test eMMC with request size
        bash $MFG_SOURCE_DIR/storageTest_sequential.sh $FOLDER_PATH_EMMC_TEST_AREA $test_size $test_round

        ## finish test so release resource.
        rm -rf $FOLDER_PATH_EMMC_TEST_AREA
        umount $FOLDER_PATH_EMMC
        rm -rf $FOLDER_PATH_EMMC
    fi
}

function Check_USB_And_Test()
{
    # Through oppsite way to filter out USB.
    usb_location=$( ls -al /dev/disk/by-id/ | grep "usb" | sed -e "/$EMMC_LABEL/d" | sed -n '$p' | cut -d '/' -f 3 )
    if [[ -z "$usb_location" ]];then
        printf " ---- USB test Start ----\n\n" |& tee -a $toAllLog
        echo " USB is not inserted." |& tee -a $toAllLog
        # printf "  ====> USB Test FAIL\n\n" |& tee -a $toAllLog
        printf " ---- USB test End ----\n" |& tee -a $toAllLog
    else
        printf ' USB locates at %s\n' $usb_location

        # Then do read-write test with 64M (we defined volumn)
        if [ ! -d "$FOLDER_PATH_USB" ]; then
            mkdir $FOLDER_PATH_USB
        fi
        check_existance=$( mount | grep "$FOLDER_PATH_USB" )
        if [[ -z $check_existance ]]; then
            mount /dev/$usb_location $FOLDER_PATH_USB
        fi
        if [ ! -d "$FOLDER_PATH_USB_TEST_AREA" ]; then
            mkdir $FOLDER_PATH_USB_TEST_AREA
        fi

        ## fork a thread to test USB with request size
        bash $MFG_SOURCE_DIR/storageTest_sequential.sh $FOLDER_PATH_USB_TEST_AREA $test_size $test_round

        ## finish test so release resource.
        rm -rf $FOLDER_PATH_USB_TEST_AREA
        umount $FOLDER_PATH_USB
        rm -rf $FOLDER_PATH_USB
    fi
}

function Check_SSD_And_Test()
{
    if (( ! $ONIE_ACCESS_WAY )); then    ## orign MFG
        ssd_location=$( ls -al /dev/disk/by-id/ | grep "$SSD_LABEL" | sed -n '$p' | cut -d '/' -f 3 )
    else                                 ## ONIE layout
        if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
            ssd_location=$( blkid | grep "PEGATRON-DIAG" | awk '{print $1}' | cut -d ':' -f 1 | cut -d '/' -f 3 )
        else
            ssd_location=$( ls -al /dev/disk/by-id/ | grep "$SSD_LABEL" | sed -n '4p' | cut -d '/' -f 3 )    ## sd*3
        fi
    fi

    if [[ -z "$ssd_location" ]];then
        printf " ---- SSD test Start ----\n\n" |& tee -a $toAllLog
        echo " SSD is not inserted." |& tee -a $toAllLog
        # printf "  ====> SSD Test FAIL\n\n" |& tee -a $toAllLog
        printf " ---- SSD test End ----\n" |& tee -a $toAllLog
    else
        printf ' SSD locates at %s\n' $ssd_location

        if [ ! -d "$FOLDER_PATH_SSD" ]; then    ## if folder already exist, skip create new folders.
            mkdir $FOLDER_PATH_SSD
        fi
        # Then do read-write test with 64M (we defined volumn)
        checkExist=$( mount | grep "$FOLDER_PATH_SSD" )
        if [[ -z $checkExist ]]; then
            mount /dev/$ssd_location $FOLDER_PATH_SSD
        fi
        if [ ! -d "$FOLDER_PATH_SSD_TEST_AREA" ]; then
            mkdir $FOLDER_PATH_SSD_TEST_AREA
        fi

        ## fork a thread to test SSD with request size
        bash $MFG_SOURCE_DIR/storageTest_sequential.sh $FOLDER_PATH_SSD_TEST_AREA $test_size $test_round

        ## finish test so release resource.
        rm -rf $FOLDER_PATH_SSD_TEST_AREA
        umount $FOLDER_PATH_SSD
        rm -rf $FOLDER_PATH_SSD
    fi
}

if [[ $# < 1 ]]; then
    echo " Please enter [test size]"
    exit 1;
elif [[ $# == 1 ]]; then
    test_size=$1
    test_round=1
else
    test_size=$1
    test_round=$2

    if [[ ! -z "$3" ]]; then
        if [[ "$3" == "USB" ]]; then
            Check_USB_And_Test
        elif [[ "$3" == "SSD" ]]; then
            Check_SSD_And_Test
        elif [[ "$3" == "eMMC" ]]; then
            Check_EMMC_RW_Partition_And_Test
        fi
        exit 1
    fi
fi
Log_Name_Check $test_round

printf "[MFG] Start peripheral (DRAM, eMMC, USB and SSD test) with size %d MB. \n" $test_size
printf "Test Start : " |& tee -a $toAllLog
timestamp |& tee -a $toAllLog
echo "  " >> $toAllLog

## excute excution and scripts:
# DRAM, force test 16M once.
byte="M"
outputParam=16$byte ## $test_size$byte
#echo $outputParam
bash $MFG_SOURCE_DIR/DDR_test.sh $outputParam 1 "consoleON" $test_round

# eMMC test
Check_EMMC_RW_Partition_And_Test

# usb check inserted or not, then do read-write test.
Check_USB_And_Test

# SSD check and rw test.
if [[ "$PROJECT_NAME" != "GEMINI" ]]; then        ## 20200914 PT request skip SSD test of burn-in mode, to prevent adding bad block.
    Check_SSD_And_Test
fi

printf "Test End : " |& tee -a $toAllLog
timestamp |& tee -a $toAllLog
echo "  "
echo "=======================" >> $toAllLog

