#!/bin/bash
##########################################################################################
# $1 is IP for DUT.
# $2 is IP address to ping
# $3 is test time long, default is non-stop ; n = n seconds later call stop automatically.
# $4 is to show on console or not.
# $5 is test Round , default 0
# If OOB ping test without enter "test time" parameter,
#   and you want to stop OOB ping test by manually, use following command to stop it.
#   "source /home/root/mfg/mfg_sources/OOB_ping_test_stop.sh"
##########################################################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh


function Log_Name_Check() # $1: testRound
{
    if [ ! -z "$1" ]; then
        test_log="$LOG_PATH_OOB/OOB_ping_test_$1.log";
    else
        test_log="$LOG_PATH_OOB/OOB_ping_test.log"
    fi

    ## if older exist, remove it first.
    if [ -f "$test_log" ]; then rm "$test_log"; fi
}

function Parse_OOB_Result
{
    OOB_test_result=$FALSE

    readarray log_array < "$test_log"
    log_line_num=${#log_array[@]}
    #echo "[Debug] log_line_num ---> $log_line_num"

    for (( line_index = 0 ; line_index < $log_line_num ; line_index += 1 ))
    do
        string=$( echo "${log_array[$line_index]}" )
        #printf "[Debug] str ---> %s\n" "$string"

        if [[ "$string" == *", 0% packet loss"* ]]; then
            OOB_test_result=$TRUE
            break
        fi
    done

    if (( $OOB_test_result == $TRUE )); then
        printf "\n ===> OOB Test PASS\n" |& tee -a $test_log
    elif (( $OOB_test_result == $FALSE )); then
        printf "\n ===> OOB Test FAIL\n" |& tee -a $test_log
    fi
}

Log_Name_Check $5

if (( $# < 2 )); then
    echo " # Need at least 2 parameters : First is DUT_IP , second is target IP to ping. "
    echo "     ( optional : [ping times] [output (consoleON / consoleOFF) ] "
    # dut_ip="192.168.1.123"
    echo " # Default IP set to 192.168.1.1 "
    exit 1
else
    dut_ip=$1
    to_ping=$2
    if [[ ! -z "$4" && "$4" == "consoleOFF" ]]; then
        console="no"
    else
        console="yes"
    fi

    ## init DUT IP first.
    ifconfig $ETHTOOL_NAME $dut_ip    # netmask "255.255.255.0"
    sleep 3
    if [[ "$console" == "yes" ]]; then
        echo " ## IP setup done"
    fi
    sleep 1
fi

echo ""
echo " ## Start OOB ping test ... "
printf "====================================================\n\n" >> $test_log
if [[ "$console" == "yes" ]]; then
    timestamp |& tee -a $test_log
else
    timestamp &>> $test_log
fi

if [[ ! -z "$3" ]]; then
    ping -c $3 $to_ping >> $test_log    ## ping request times
    sleep 1
    Parse_OOB_Result
else
    echo " ## If want to stop test, please execute another commnad './mfg_sources/OOB_ping_test_stop.sh'. "
    ping $to_ping >> $test_log &        ## endless ping ...
fi

