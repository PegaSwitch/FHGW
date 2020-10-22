#!/bin/bash
#############################################################
# 20190409 Jenny Add for Denverton
# For RTC workaround use.
# ! leap year design is rough, not full truely function !!!
#############################################################

function help_msg ()
{
        echo " Please enter action bit (r/w). Ex: ./dnv_rtc r"
        echo "                   if 'w' mode. Ex: ./dnv_rtc w 20190409152620"
}

if (( $# < 1 )); then
    help_msg
else
    if [[ "$1" == "w" ]]; then
        if [[ -z $2 ]]; then
            echo "Please enter setting time. EX: 20190408102730"
            exit 1
        else
            inputDate=$2

            if (( ${#inputDate} != 14 ));then
                echo " # Input out of length, only accept 14 char, EX: 20190408102730 "
                exit 1
            else
                declare -a array

                # year
                inputYear=$( { echo $inputDate | cut -c3-4 ; } 2>&1 )
                tmp_Year=$(( 10#$inputYear ))
                # month
                inputMonth=$( { echo $inputDate | cut -c5-6 ; } 2>&1 )
                tmp_Month=$(( 10#$inputMonth ))
                # date
                inputDay=$( { echo $inputDate | cut -c7-8 ; } 2>&1 )
                tmp_Day=$(( 10#$inputDay ))
                # hour
                inputHour=$( { echo $inputDate | cut -c9-10 ; } 2>&1 )
                tmp_Hour=$(( 10#$inputHour ))    # Constants with a leading 0 are interpreted as octal numbers, need to force base-10 interpretation.
                if (( $tmp_Hour < 8 )); then
                    if (( ( $tmp_Day - 1 ) == 0 )); then
                        month=$(( $tmp_Month - 1 ))
                        if (( $month == 0 )); then
                            array[2]=31
                            array[1]=12
                            array[0]=$(( $tmp_Year - 1 ))
                        elif (( $month == 2 )); then
                            if (( $tmp_Year % 4 == 0 )); then
                                array[2]=29
                            else
                                array[2]=28
                            fi
                            array[1]="0"$month
                            array[0]=$inputYear
                        elif (( $month == 4 || $month == 6 || $month == 9 || $month == 11 )); then
                            array[2]=30
                            if (( $month == 11 )); then
                                array[1]=$month
                            else
                                array[1]="0"$month
                            fi
                            array[0]=$inputYear
                        else
                            array[2]=31
                            if (( $month == 12 )); then
                                array[1]=$month
                            else
                                array[1]="0"$month
                            fi
                            array[0]=$inputYear
                        fi
                    else
                        array[2]="0"$(( $tmp_Day - 1 ))
                        array[1]=$inputMonth
                        array[0]=$inputYear
                    fi
                    array[3]=$(( $tmp_Hour + 16 ))
                else
                    array[0]=$inputYear
                    array[1]=$inputMonth
                    array[2]=$inputDay
                    array[3]=$(( $tmp_Hour - 8 ))
                fi
                # min
                inputMin=$( { echo $inputDate | cut -c11-12 ; } 2>&1 )
                tmp_Min=$(( 10#$inputMin ))
                echo $tmp_Min
                array[4]=$tmp_Min
                # sec
                array[5]=$( { echo $inputDate | cut -c13-14 ; } 2>&1 )

                ## [DEBUG]
                if (( 0 )); then
                    echo ${array[0]}
                    echo ${array[1]}
                    echo ${array[2]}
                    echo ${array[3]}
                    echo ${array[4]}
                    echo ${array[5]}
                fi
                ## Call Pegatron Hilbert's RTC workaround tool to set hwclock
                rtc w year=${array[0]} month=${array[1]} date=${array[2]} hour=${array[3]} minute=${array[4]} second=${array[5]}
                ## Set system clock
                date -s "20$inputYear-$inputMonth-$inputDay $inputHour:${array[4]}:${array[5]}"
            fi
        fi
    else    ## read RTC
        tmp_file="/tmp/rtc_read.txt"
        if [[ -f $tmp_file ]]; then
            rm $tmp_file
            rtc r >> $tmp_file
        else
            rtc r >> $tmp_file
        fi

        read_sec=$( { cat /tmp/rtc_read.txt | sed -n "1p" | cut -d ':' -f 2 | cut -c2-3 ; } 2>&1 )
        read_min=$( { cat /tmp/rtc_read.txt | sed -n "2p" | cut -d ':' -f 2 | cut -c2-3 ; } 2>&1 )
        read_hour=$( { cat /tmp/rtc_read.txt | sed -n "3p" | cut -d ':' -f 2 | cut -c2-3 ; } 2>&1 )
        read_day=$( { cat /tmp/rtc_read.txt | sed -n "4p" | cut -d ':' -f 2 | cut -c2-3 ; } 2>&1 )
        read_month=$( { cat /tmp/rtc_read.txt | sed -n "5p" | cut -d ':' -f 2 | cut -c2-3 ; } 2>&1 )
        read_year=$( { cat /tmp/rtc_read.txt | sed -n "6p" | cut -d ':' -f 2 | cut -c2-3 ; } 2>&1 )

        ## [DEBUG]
        if (( 0 )); then
            echo $read_sec
            echo $read_min
            echo $read_hour
            echo $read_day
            echo $read_month
            echo $read_year
        fi
        systemMonth=(none Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

        ## 20190516 add by PT request, to compare with command input value.
        pt_request=1
        if (( pt_request == 1 )); then
            tmp_Year=$(( 10#$read_year ))
            tmp_Month=$(( 10#$read_month ))
            tmp_Day=$(( 10#$read_day ))
            tmp_Hour=$(( 10#$read_hour ))
            tmp_hour=$(( $tmp_Hour + 8 ))

            output_hour=$(( read_hour + 8 ))
            if (( $output_hour >= 24 )); then
                output_hour=$(( $output_hour - 24 ))
                output_day=$(( $read_day + 1 ))
                if (( $tmp_hour >= 24 )); then
                    output_hour=$(( $tmp_hour - 24 ))
                    ## check days of month
                    if (( $tmp_Month == 12 )); then
                        limitday=31
                    elif (( $tmp_Month == 2 )); then
                        if (( $tmp_Year % 4 == 0 )); then
                           limitday=29
                        else
                           limitday=28
                        fi
                    elif (( $tmp_Month == 4 || $tmp_Month == 6 || $tmp_Month == 9 || $tmp_Month == 11 )); then
                        limitday=30
                    else
                        limitday=31
                    fi
                    ##
                    if (( ( $tmp_Day + 1 ) > limitday )); then
                        if (( $tmp_Month == 12 )); then
                            output_year=$(( $tmp_Year + 1 ))
                            output_month=1
                        else
                            output_month=$(( $tmp_Month + 1 ))
                            output_year=$tmp_Year
                        fi
                        output_day=1
                    else
                        output_day=$(( $tmp_Day + 1 ))
                        output_month=$tmp_Month
                        output_year=$tmp_Year
                    fi
                fi
            else
                output_day=$read_day
                output_month=$tmp_Month
                output_year=$tmp_Year
            fi
            echo " " ${systemMonth[$output_month]} $output_day $output_hour":"$read_min":"$read_sec "20"$output_year
        else    # Add End
            echo " " ${systemMonth[$read_month]} $read_day $read_hour":"$read_min":"$read_sec "20"$read_year
        fi
    fi
fi
