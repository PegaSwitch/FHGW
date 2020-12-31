#!/bin/bash

# way 3: use both caculate, and bzip2 to compress random data, to make CPU full loading.
# Usage:  [number_of_cpus_to_load] [number_of_seconds]

function Infinite_Loop ()
{
    _thread=$1

    endtime=$(( $(date +%s) + $duration ))
    while (( $(date +%s) < $endtime ));
    do
        #echo $(date +%s)
        echo $((13**99)) 1>/dev/null 2>&1
        # $( dd if=/dev/urandom count=10000 | bzip2 -9 >> /dev/null ) 2>&1 >&/dev/null
        $( dd if=/dev/urandom count=10000 &> /tmp/tmp_cpu.tmp | bzip2 -9 >> /dev/null )
    done
    echo " # Done Stressing the system - for thread $_thread"
}

if (( $# < 2 )); then
    echo " @ Usage : ./mfg_sources/cpu_gain_loading.sh 4 60  (4 threads for 60 secs)"
    exit 0
else
    ## Define variables
    processors_number=${1:-4}    # How much scaling you want to do
    duration=${2:-20}            # seconds

    echo " # Running for duration " $duration " secs, spawning " $processors_number " threads in background."
    for i in `seq ${processors_number}` ;
    do
        # Put an infinite loop
        Infinite_Loop $i &
    done
    echo " "
fi

