#! /bin/bash
############################################################
# This script is to monitor all hardware detail information.
# $1 execution times.
# $2 sleep time per round.
# $3 logName index
############################################################

source ${HOME}/mfg/mfg_sources/platform_detect.sh


function Log_Name_Check() # $1: testRound
{
    # check log file
    if [ -z "$1" ]; then
        testLog="$LOG_PATH_HWMONITOR/hw_monitor.log"
    else
        testLog="$LOG_PATH_HWMONITOR/hw_monitor_$1.log"
    fi
    ## if [ -f "$testLog" ]; then rm "$testLog"; fi    ## mark off for looping test.
}

function Do_Monitor()
{
    if [ -f "$HW_MONITOR_DONE_NODE" ]; then
        rm $HW_MONITOR_DONE_NODE
    fi

    echo "[MFG] Hardware Monitor Information:"

    # Print ADC
    bash $MFG_SOURCE_DIR/adc_monitor.sh
    printf "\n"

    # ======================================================================================================================== #

    # Print Fan Status
    bash $MFG_SOURCE_DIR/fan_monitor.sh
    printf "\n"

    # ======================================================================================================================== #

    # Print Temperature
    bash $MFG_SOURCE_DIR/temp_monitor.sh
    printf "\n"

    # ======================================================================================================================== #

    # Print Multiphase controller information
    bash $MFG_SOURCE_DIR/multiphase_controller_monitor.sh
    printf "\n"

    # ======================================================================================================================== #

    # Print PSU Information
    bash $MFG_SOURCE_DIR/psu_monitor.sh
    printf "\n"

    # ======================================================================================================================== #

    touch $HW_MONITOR_DONE_NODE
}

function Input_Help()
{
    input_string=$1

    if [[ $input_string == "-h" ]] || [[ $input_string == "-help" ]] || [[ $input_string == "--h" ]] ||
       [[ $input_string == "--help" ]] || [[ $input_string == "?" ]]; then
        Help_Message
        exit 1
    fi
}

function Help_Message()
{
    echo ""
    echo "  [MFG] Hardware Monitor help message:"
    echo "    Ex: ./hw_monitor"
    echo "    Ex: ./hw_monitor [execution times] [waitTime (sec) per round] [log number]"
    echo ""
}

#
# Main
#
Input_Help $1
Log_Name_Check $3

# ------------------------------------------------------------------------------------------------------------------------ #

execution_times=0

if (( $# < 1 )); then
    Do_Monitor

elif (( $1 == 1 )); then
    timestamp &>> $testLog
    Do_Monitor &>> $testLog

else
    if [[ -z "$2" ]]; then
        echo " Please enter waitTime per round."
        exit 1
    else
        waitTime=$2
    fi

    request_execute=$1

    while :
    do
        execution_times=$(( $execution_times + 1 ))
        timestamp &>> $testLog
        Do_Monitor &>> $testLog
        if (( $execution_times == $request_execute )); then
            break
        fi

        sleep $waitTime
    done
fi
