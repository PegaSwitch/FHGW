#!/bin/bash

###################################################################
# Add for monitor CPU loading, requested by EDVT
# $1 is output times, 0 = infinite times ; n = total long times
# If user didn't input $2, default is 30 second output once.
###################################################################

function Show_CPU_Loading_Percentage ()
{
    user_percentage=$( top -bn1 | grep "CPU:" | sed -n "1p" | cut -d '%' -f 1 | cut -c7- )
    # echo $user_percentage

    system_percentage=$( top -bn1 | grep "CPU:" | sed -n "1p" | cut -d '%' -f 2 | cut -c7- )
    # echo $system_percentage

    total_percentage=$(( $user_percentage + $system_percentage ))
    #echo $total_percentage
    printf "\n # CPU loading = %d %% ( user: %d %% , system: %d %% ) \n\n" $total_percentage $user_percentage $system_percentage
}

if (( $# < 1 )); then
    echo " # request 2 input : total_long_time & period_of_time"
    Show_CPU_Loading_Percentage
else
    ## variable define
    total_time=$1
    if (( $total_time == 0 )); then
        end_time=604800    # 7-day
    else
        end_time=$(( $(date +%s) + $total_time ))
    fi

    if [[ -z $2 ]]; then
        period_time=30
    else
        period_time=$2
    fi

    ## Start to show
    while (( $(date +%s) < $end_time ));
    do
        Show_CPU_Loading_Percentage
        sleep $period_time
    done
fi

