#!/bin/bash

######################################################
# This script is to do dram test.
# $1 = testSize with M
# $2 = test times
# $3 = show on console on or off (default is consoleON)
# $4 = test Round , default 0
# $5 = execute loop times , default x (once)
######################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh


function Print_Start_Message ()
{
    if [[ $console == "on" ]]; then
        printf " Start : " |& tee -a $test_log
        timestamp |& tee -a $test_log
    else
        printf " Start : " &>> $test_log
        timestamp &>> $test_log
    fi
}

function Print_End_Message ()
{
    _continue_flag=$1

    if [[ $console == "on" ]]; then
        printf " End : " |& tee -a $test_log
        timestamp |& tee -a $test_log
        echo "------------------------------" >> $test_log
        if [[ "$_continue_flag" == "once" ]]; then
            echo " ---- RAM test End ----" |& tee -a $to_all_log
        fi
        echo "  " |& tee -a $to_all_log
    else
        printf " End : " &>> $test_log
        timestamp &>> $test_log
        if [[ "$_continue_flag" == "once" ]]; then
            echo " ---- RAM test End ----" &>> $to_all_log
        fi
        echo "  " &>> $to_all_log
    fi
}

function Log_Name_Check() # $1: testRound
{
    if [ ! -z "$1" ]; then
        to_all_log="$LOG_PATH_STORAGE/peripheral_test_$1.log";
        test_log="$LOG_PATH_STORAGE/mem_test_$1.log";
    else
        to_all_log="$LOG_PATH_STORAGE/peripheral_test.log"
        test_log="$LOG_PATH_STORAGE/mem_test.log"
    fi

    ## if older exist, remove it first.
    if [ -f "$test_log" ]; then rm "$test_log"; fi
}

function Do_DDR_Test ()
{
    ## excute tool 'memtester' to check dram, can decide test size (in B/K/M/G) and test rounds.
    memtester -f $test_log -l $to_all_log -s $console $1 $2     # format ex. memtester 1024M 2 , means test 1G ram twice.
}

if (( $# < 2 )); then
    echo " # Need to enter [testSize in MB] and [testTimes] and [consoleON / consoleOFF]"
    exit 1
else
    test_size=$1
    test_rounds=$2

    ## value yes / no are combined to memtester file, so if modified here, should also modify the memtester execution.
    if [[ ! -z "$3" && "$3" == "consoleOFF" ]]; then
        console="no"
    else    # "$3" exist || "$3" == "consoleON"
        console="yes"
    fi

    ## decide log naming.
    if [[ ! -z "$4" ]]; then
        Log_Name_Check $4
    else 
        Log_Name_Check
    fi

    echo ""
    echo " ## DRAM test Start"
    if [[ $console == "on" ]]; then
        echo " ---- RAM test Start ----" |& tee -a $to_all_log
    else
        echo " ---- RAM test Start ----" &>> $to_all_log
    fi

    ## execute once or infinite loop
    if [[ -z "$5" ]]; then
        Print_Start_Message
        Do_DDR_Test $test_size $test_rounds
        Print_End_Message "once"
    else
        endtime=$(( $(date +%s) + $5 ))
        while (($(date +%s) < $endtime));
        do
            Print_Start_Message
            Do_DDR_Test $test_size $test_rounds
            Print_End_Message
            sleep 10
        done
    fi

    echo ""
    echo " ## DRAM test End"
    echo ""
fi

