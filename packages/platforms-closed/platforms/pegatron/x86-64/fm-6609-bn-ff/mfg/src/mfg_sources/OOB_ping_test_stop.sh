#!/bin/bash

timestamp() {
        date +"%Y-%m-%d %H:%M:%S"
}

function Log_Name_Check ()
{
    test_log="$logFolder/OOB_ping_test.log"     #### !!! need support test_*.log !!!
}

Log_Name_Check

echo " # Will stop OOB ping test immediately..."
killall ping
sleep 1
pid=$( { ps | grep "OOB_ping" | grep -v "grep" | awk '{print $1}' ; } 2>&1 )
if [[ ! -z $pid ]]; then
    kill -9 $pid
fi

if [[ -f "$test_log" ]]; then
    echo " " &>> $test_log
    timestamp |& tee -a $test_log
    printf " ==== OOB test Stop , by maually forced. ====\n" |& tee -a $test_log
fi

