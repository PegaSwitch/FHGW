#!/bin/bash

##############################################################
# This script is use for stop storage test in the background.
##############################################################

testLog="$LOG_PATH_STORAGE/peripheral_test.log"

timestamp() {
        date +"%Y-%m-%d %H:%M:%S"
}

echo " # Will stop storage test ..."
if [[ -f "$testLog" ]]; then
    echo " " &>> $testLog
    timestamp |& tee -a $testLog
    printf " ==== Storage test Stop , by maually forced. ====\n" |& tee -a $testLog
fi

pidList=$( { ps | grep "peripheral" | grep -v "grep" | awk '{print $1}' ; } 2>&1 )
#echo $pidList
kill -9 $pidList

pidList2=$( { ps | grep "storageTest" | grep -v "grep" | awk '{print $1}' ; } 2>&1 )
#echo $pidList2
kill -9 $pidList2

