#!/bin/bash

#########################################################################################
# This script is to start peripheral test, include dram,storage(eMMC/USB/SSD).
# $1 is user decide the test size ;
# $2 is test items count
# $3 is whether output to console ;
# $4 is decide execute time long (orig ver=once/loop.)
# $5 is cycle number (for log named used)
# $6 is round number  (for log named used)
#########################################################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh


function Log_Name_Check() # $1: testCycle, $2: testRound
{
    if [ -z "$1" ]; then
        testCycle=0
        toAllLog="$LOG_PATH_STORAGE/peripheral_test_0.log"
        usbLog="$LOG_PATH_STORAGE/usb_test_0.log"
        emmcLog="$LOG_PATH_STORAGE/emmc_test_0.log"
        ssdLog="$LOG_PATH_STORAGE/ssd_test_0.log"
    else
        testCycle=$1
        if [ ! -z "$2" ]; then
            testRound=$2
            toAllLog="$LOG_PATH_STORAGE/peripheral_test_$1_$2.log"
            usbLog="$LOG_PATH_STORAGE/usb_test_$1_$2.log"
            emmcLog="$LOG_PATH_STORAGE/emmc_test_$1_$2.log"
            ssdLog="$LOG_PATH_STORAGE/ssd_test_$1_$2.log"
        else
            toAllLog="$LOG_PATH_STORAGE/peripheral_test_$1.log"
            usbLog="$LOG_PATH_STORAGE/usb_test_$1.log"
            emmcLog="$LOG_PATH_STORAGE/emmc_test_$1.log"
            ssdLog="$LOG_PATH_STORAGE/ssd_test_$1.log"
        fi
    fi

    ## if older exist, remove it first.
    if [ -f "$toAllLog" ]; then rm "$toAllLog"; fi
    if [ -f "$usbLog" ]; then rm "$usbLog"; fi
    if [ -f "$emmcLog" ]; then rm "$emmcLog"; fi
    if [ -f "$ssdLog" ]; then rm "$ssdLog"; fi
}

function Check_EMMC_RW_Partition_And_Test ()
{
    if (( $emmc_not_exist == $TRUE ));then
        if [[ "$output_to_console" == "yes" ]]; then
            printf " ---- eMMC test Start ----\n\n"
            echo " eMMC is not inserted." |& tee -a $toAllLog
            # printf "  ====> eMMC Test FAIL\n\n" |& tee -a $toAllLog
            printf " ---- eMMC test End ----\n"
        else
            echo " eMMC is not inserted." &>> $toAllLog
            # printf "  ====> eMMC Test FAIL\n\n" &>> $toAllLog
        fi
        # exit 1
    else
        ## Check if disk is mounted already (maybe this script had run before), or mount up.
        check_mount_status=$( { mount | grep "$FOLDER_PATH_EMMC" ; } 2>&1 )
        if [[ ! -z "$check_mount_status" ]]; then
            if [[ "$output_to_console" == "yes" ]]; then
                echo " eMMC is already mounted."
            fi
        else
            if [ ! -d "$FOLDER_PATH_EMMC" ]; then    ## if folder already exist, skip create new folders.
                mkdir $FOLDER_PATH_EMMC
                sync
            fi

            ## mount r/w test partition.
            emmc_lastpart=$( ls -al /dev/disk/by-id/ | grep "$EMMC_LABEL" | sed -n '$p' | cut -d '/' -f 3 )
            emmc_disk=$( echo $emmc_lastpart | cut -c1-3 )
            if (( $ONIE_ACCESS_WAY == 0 )); then
                mount /dev/$emmc_lastpart $FOLDER_PATH_EMMC    # define test area(/dev/sd*4)
            else
                if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
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
            sync
        fi
        check_mount_status=$( { mount | grep "$FOLDER_PATH_EMMC" | awk '{print $1}' | cut -d ':' -f 1 | cut -d '/' -f 3 ; } 2>&1 )
        if [[ "$output_to_console" == "yes" ]]; then
            printf ' eMMC test partition is %s\n' $check_mount_status
        fi

        ## fork a thread to test eMMC with request size
        bash $MFG_SOURCE_DIR/storageTest_parallel.sh $FOLDER_PATH_EMMC_TEST_AREA $test_size $output_to_console $testCycle $testRound &
    fi
}

function Check_USB_And_Test ()
{
    # Through oppsite way to filter out USB.
    usb_location=$( ls -al /dev/disk/by-id/ | grep "usb" | sed -e "/$EMMC_LABEL/d" | sed -n '$p' | cut -d '/' -f 3 )
    if [[ -z "$usb_location" ]];then
        if [[ "$output_to_console" == "yes" ]]; then
            printf " ---- USB test Start ----\n\n"
            echo " USB is not inserted." |& tee -a $toAllLog
            # printf "  ====> USB Test FAIL\n\n" |& tee -a $toAllLog
            printf " ---- USB test End ----\n"
        else
            echo " USB is not inserted." &>> $toAllLog
            # printf "  ====> USB Test FAIL\n\n" &>> $toAllLog
        fi
    else
        if [[ "$output_to_console" == "yes" ]]; then
            printf ' USB locates at %s\n' $usb_location
        fi

        if [ ! -d "$FOLDER_PATH_USB" ]; then
            mkdir $FOLDER_PATH_USB
            sync
        fi
        check_existance=$( mount | grep "$FOLDER_PATH_USB" )
        if [[ -z $check_existance ]]; then
            mount /dev/$usb_location $FOLDER_PATH_USB
        fi

        ## Then do r/w test
        if [ ! -d "$FOLDER_PATH_USB_TEST_AREA" ]; then
            mkdir $FOLDER_PATH_USB_TEST_AREA
            sync
        fi
        bash $MFG_SOURCE_DIR/storageTest_parallel.sh $FOLDER_PATH_USB_TEST_AREA $test_size $output_to_console $testCycle $testRound &    # fork a thread to test USB with request size
    fi
}

function Check_SSD_And_Test ()
{
    if (( ! $ONIE_ACCESS_WAY )); then    ## orign MFG
        ssd_location=$( ls -al /dev/disk/by-id/ | grep "$SSD_LABEL" | sed -n '$p' | cut -d '/' -f 3 )
    else                                 ## ONIE layout
        if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
            ssd_location=$( blkid | grep "PEGATRON-DIAG" | awk '{print $1}' | cut -d ':' -f 1 | cut -d '/' -f 3 )
        else
            ssd_location=$( ls -al /dev/disk/by-id/ | grep "$SSD_LABEL" | sed -n '4p' | cut -d '/' -f 3 )    ## sd*3
            ## for checking pure SSD (only for r/w test requirement)
            if [[ -z "$ssd_location" ]];then
                ssd_check_exist=$( ls -al /dev/disk/by-id/ | grep "$SSD_LABEL" )
                if [[ ! -z "$ssd_check_exist" ]];then
                    ssd_location=$( ls -al /dev/disk/by-id/ | grep "$SSD_LABEL" | sed -n '2p' | cut -d '/' -f 3 )    ## re-assign as sd*1
                fi
            fi
        fi
    fi

    if [[ -z "$ssd_location" ]];then
        if [[ "$output_to_console" == "yes" ]]; then
            printf " ---- SSD test Start ----\n\n"
            echo " SSD is not inserted." |& tee -a $toAllLog
            # printf "  ====> SSD Test FAIL\n\n" |& tee -a $toAllLog
            printf " ---- SSD test End ----\n"
        else
            echo " SSD is not inserted." &>> $toAllLog
            # printf "  ====> SSD Test FAIL\n\n" &>> $toAllLog
        fi
    else
        if [[ "$output_to_console" == "yes" ]]; then
            printf ' SSD locates at %s\n' $ssd_location
        fi

        if [ ! -d "$FOLDER_PATH_SSD" ]; then
            mkdir $FOLDER_PATH_SSD
        fi
        check_existance=$( mount | grep "$FOLDER_PATH_SSD" )
        if [[ -z "$check_existance" ]]; then
            mount /dev/$ssd_location $FOLDER_PATH_SSD
        fi

        ## Then do r/w test
        if [ ! -d "$FOLDER_PATH_SSD_TEST_AREA" ]; then
            mkdir $FOLDER_PATH_SSD_TEST_AREA
        fi
        bash $MFG_SOURCE_DIR/storageTest_parallel.sh $FOLDER_PATH_SSD_TEST_AREA $test_size $output_to_console $testCycle $testRound &    # fork a thread to test SSD with request size
    fi
}

function Main_Storage_Test ()
{
    printf "Test Start : " |& tee -a $toAllLog
    timestamp |& tee -a $toAllLog
    echo "  " >> $toAllLog

    ## excute excution and scripts:
    # DRAM, 64M test once.
    # bash $MFG_SOURCE_DIR/DDR_test.sh 64M 1 &

    ## By user demand to call test items
    if [[ $test_item_amount == 1 ]];then      # test 1 item - emmc
        Check_EMMC_RW_Partition_And_Test
    elif [[ $test_item_amount == 2 ]];then    # test 2 items - emmc/usb
        Check_EMMC_RW_Partition_And_Test
        sleep 1
        Check_USB_And_Test    # usb check inserted or not, then do read-write test.
    elif [[ $test_item_amount == 3 ]];then    # test 3 items - emmc/usb/ssd
        Check_EMMC_RW_Partition_And_Test
        sleep 1
        Check_USB_And_Test
        sleep 1
        Check_SSD_And_Test
    elif [[ $test_item_amount == 4 ]];then    # test 4 items - emmc/usb/ssd/spi flash
        Check_EMMC_RW_Partition_And_Test
        sleep 1
        Check_USB_And_Test
        sleep 1
        Check_SSD_And_Test
        sleep 1
        #if [ ! -d "/sys/firmware/efi/efivars" ] ; then    # not BIOS
            bash $MFG_SOURCE_DIR/SPI_test.sh 1024 $time_long 60 $output_to_console $testCycle $testRound &    # test 1KB size ( 0 is for recursive test 30 days), and each gap time 1 mins.
        #fi
    fi

    ## wait sub-process excution over.
    for job in `jobs -p`
    do
        if [[ "$output_to_console" == "yes" ]]; then
            echo "Wait job: ${job}"
        fi
        wait $job
    done

    ## remove resources
    if [[ ! -z $FOLDER_PATH_EMMC ]]; then
        check_existance=$( mount | grep "$FOLDER_PATH_EMMC" )
        if [[ ! -z $check_existance ]]; then
            fuser -k $FOLDER_PATH_EMMC
            umount $FOLDER_PATH_EMMC
            rm -rf $FOLDER_PATH_EMMC
        fi
    fi
    if [[ ! -z $FOLDER_PATH_USB ]]; then
        check_existance=$( mount | grep "$FOLDER_PATH_USB" )
        if [[ ! -z $check_existance ]]; then
            fuser -k $FOLDER_PATH_USB
            umount $FOLDER_PATH_USB
            rm -rf $FOLDER_PATH_USB
        fi
    fi
    if [[ ! -z $FOLDER_PATH_SSD ]]; then
        check_existance=$( mount | grep "$FOLDER_PATH_SSD" )
        if [[ ! -z $check_existance ]]; then
            fuser -k $FOLDER_PATH_SSD
            umount $FOLDER_PATH_SSD
            rm -rf $FOLDER_PATH_SSD
        fi
    fi

    printf "Test End : " |& tee -a $toAllLog
    timestamp |& tee -a $toAllLog
    echo "  "
    echo "=======================" >> $toAllLog
}

## by test size and items number to decide how long to wait
# $1 is test size ; $2 is test items count
test_size=$1

test_item_amount=$2
if [[ $test_item_amount == 4 ]]; then
    test_items="eMMC/USB/SSD/SPI"
elif [[ $test_item_amount == 3 ]]; then
    test_items="eMMC/USB/SSD"
elif [[ $test_item_amount == 2 ]]; then
    test_items="eMMC/USB"
elif [[ $test_item_amount == 1 ]]; then
    test_items="eMMC"
else
    echo "Please enter [test size] and how many [items counts] you want to test"
    exit 1
fi

## whether output on console
if [[ -z "$3" || "$3" == "yes" ]]; then
    output_to_console="yes"                 # default output both on console and log file.
else
    output_to_console="no"
fi

## log naming
if [[ ! -z "$6" ]]; then
    Log_Name_Check $5 $6
else
    Log_Name_Check $5
fi

printf "[MFG] Start peripheral - %s test\n" $test_items
## execute once on infinite loop
if [[ -z "$4" ]]; then
    Main_Storage_Test    # test once
else
    time_long=$4
    endtime=$(($(date +%s) + $4))

    while (($(date +%s) < $endtime));
    do
        Main_Storage_Test

        if ((($(date +%s) + 45 ) < $endtime)); then    ## 45 = sleep 30 + buf execute 15 sec.
            if (( $time_long >= 120 )); then
                sleep 30
            else
                sleep 5
            fi
        fi
    done
fi
