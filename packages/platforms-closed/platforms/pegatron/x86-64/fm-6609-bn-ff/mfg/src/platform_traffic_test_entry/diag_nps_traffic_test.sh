#!/bin/bash

# Following are parameters definition.
{
    source /home/root/mfg/mfg_sources/platform_detect.sh

    # Parameter for Debug
    DBG_MODE=0

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # Constant Variable Define
    curr_pwr_cyc_round=${1:-"1"}
    curr_burn_in_cyc_round=${2:-"1"}
    shift 2

    tfc_mode_sel=${1:-"2"}
    tfc_pkt_time=${2:-"1"}
    shift 2

    sfp_speed=${1:-"25"}
    qsfp_speed=${2:-"100"}
    loopback_test_pkt_num=${3:-"100"}
    loopback_test_iteration=${4:-"100"}
    shift 4

    case $qsfp_speed in
        100|40)
            port_start_index=0
            port_end_index=53
            ;;
        50)
            port_start_index=0
            port_end_index=59
            ;;
        25|10)
            port_start_index=0
            port_end_index=63
            ;;
        *)
            echo "[Diag Error Msg] Wrong QSFP Speed Setting !!!"
            ;;
    esac


    TRAFFIC_TEST_MODE_EDVT=1
    TRAFFIC_TEST_MODE_PT_PRETEST=2
    TRAFFIC_TEST_MODE_PT_BURNIN=3

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # Working Directory Define
    if (( $DBG_MODE == $TRUE )); then
        TRAFFIC_TEST_LOG_DIR="/home/root/Desktop/diag_test/log"
    else
        TRAFFIC_TEST_LOG_DIR=$LOG_PATH_MAC
    fi

    #TRAFFIC_TEST_LOG_FILE_NAME=${TRAFFIC_TEST_LOG_DIR}/diag_nps_traffic_test_$curr_pwr_cyc_round.log
    PRETEST_LOG_FILE_NAME=${TRAFFIC_TEST_LOG_DIR}/diag_nps_pretest.log
    BURNIN_LOG_FILE_NAME=${TRAFFIC_TEST_LOG_DIR}/diag_nps_burnin.log
    FINAL_TRAFFIC_TEST_RESULT_LOG="$LOG_DIAG_TRAFFIC_RESULT_TMP"

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # Traffic Test Result Flag
    NPS_SDK_INIT_STATUS=$PASS
    PORT_LINK_DOWN_RETRY_OVER_FLAG=$FALSE  # port link-down retry times flag [0:under / 1:over]
    PKT_LOSS_FLAG=$FALSE                   # packet loss flag [0:no / 1:yes]
    LOCAL_TRAFFIC_TEST_RESULT=$PASS
}

# ======================================================================================================================================= #

# If using Nephos loopback test command, you can use this function to parsing result.
function Parsing_Nephos_Traffic_Test_Result_For_PT_PreTest()
{
    printf "\n*** Show Pre-Test Result ***\n"

    # Using Nephos SDK loopback test command.
    while read string
    do
        error_keyStr=${string:0:11}
        if [[ "$error_keyStr" == "***Error***" ]]; then
            LOCAL_TRAFFIC_TEST_RESULT=$FAIL

            port_index_str_start=17
            for (( i = $port_index_str_start; i <= ${#string}; i += 1 ))
            do
                # string : ***Error***, port 48 cannot link-up.
                # Find "cannot" to know end of port index.
                cannot_keyStr=${string:$i:6}
                if [[ "$cannot_keyStr" == "cannot" ]]; then
                    port_index_str_end=$(( $i - 1 ))
                    port_index_strlen=$(( $port_index_str_end - $port_index_str_start + 1 ))
                    port_index_str=${string:$port_index_str_start:$port_index_strlen}

                    # remove packet counter space and comma
                    link_down_port_index=$( echo "$port_index_str" | sed 's/[[:blank:]]//g' )
                    #printf "[Debug] Link-Down Port Index ---> %d\n" "$link_down_port_index"

                    break
                fi
            done
        fi

        port_keyStr=${string:0:4}
        if [[ "$port_keyStr" == "port" ]]; then
            port_index_str=${string:7}

            # By pass TX and RX packet count string
            for (( i = 1; i <= 3; i += 1 ))
            do
                read string
            done

            test_result_str=${string:13}

            if [[ "$test_result_str" == "PASS" ]] || [[ "$test_result_str" == "FAIL" ]]; then
                printf "Port[%s]   Result[ %s ]\n" $port_index_str "$test_result_str"
            fi
        fi
    done < "$TRAFFIC_TEST_LOG_FILE_NAME"
}

function Parsing_Nephos_Port_Status()
{
    # This parsing function support for only 100G.

    for (( line_index = 0; line_index <= $log_line_num; line_index += 1 ))
    do
        keyStr=${log_array[$line_index]:0:73}

        # NPS# port show property portlist=
        if [[ "$keyStr" == "port speed medium admin an  eee fec flow-ctrl status loopback cut-through" ]]; then
            #echo "[Debug] keyStr ---> $keyStr"
            portStatus_lineStart=$(( $line_index + 2 ))
            num=$(( $port_end_index - $port_start_index ))
            portStatus_lineEnd=$(( $portStatus_lineStart + $num ))
            break
        fi
    done

    printf "\n*** Show Port Status ***\n\n"
    printf "Port[Index]   Link[Status]\n"
    port_index=$(( $port_start_index + 1 ))
    for (( line_index = $portStatus_lineStart; line_index <= $portStatus_lineEnd; line_index += 1 ))
    do
        linkStatus_str=${log_array[$line_index]:46:4}
        linkStatus=$( echo "$linkStatus_str" | sed 's/[[:blank:]]//g' | sed 's/,//g' )
        echo "Port[$port_index]   Link [$linkStatus]"

        if [[ "$linkStatus" == "down" ]]; then
            #printf "[Diag Debug] Port[%d]   Link [%s]\n" $port_index $linkStatus
            PORT_LINK_DOWN_RETRY_OVER_FLAG=$TRUE
        fi

        port_index=$(( $port_index + 1 ))
    done

    printf "\n\n"
}

function Parsing_Nephos_Packet_Counter_For_PT()
{
    test_mode_sel=$1

    # This parsing function is only for show all port counters.
    if ((0)); then
        for (( i = 0; i <= $log_line_num; i += 1 ))
        do
            keyStr=${log_array[$i]:0:7}

            # NPS# stat show portlist=
            if [[ "$keyStr" == "Port: 0" ]]; then
                portCnt_lineStart=$(( $i + 1 ))
                break
            fi
        done
    fi

    # Tx and Rx counters array initialize.
    port_num=$(( $port_end_index - $port_start_index + 1 ))
    for (( i = 0; i < $port_num; i += 1 ))
    do
        tx_arr[$i]=-1
        rx_arr[$i]=-1
    done

    line_index=0 #$portCnt_lineStart
    portIndex_keyStr_findFlag=$FALSE

    while (( $line_index <= $log_line_num ))
    do
        string=${log_array[$line_index]}
        strLen=${#string}

        if (( $portIndex_keyStr_findFlag == $FALSE )); then
            portIndex_keyStr=${string:0:5}

            if [[ "$portIndex_keyStr" == "Port:" ]]; then
                portIndex_str=${string:6:3}

                # Remove space and end of string character from port index string.
                portIndex=$( echo "$portIndex_str" | sed 's/[[:blank:]]//g' | sed 's/[[:cntrl:]]//g' )
                #printf "[Debug] portIndex ---> %d\n" $portIndex
                line_index=$(( $line_index + 2 ))
                portIndex_keyStr_findFlag=$TRUE
            else
                line_index=$(( $line_index + 1 ))
            fi
        elif (( $portIndex_keyStr_findFlag == $TRUE )); then
            pktCnt_keyStr=${string:0:10}
            #printf "[Debug] pktCnt_keyStr ---> %s\n" "$pktCnt_keyStr"

            if [[ "$pktCnt_keyStr" == "RX uc pkts" ]] || [[ "$pktCnt_keyStr" == "TX uc pkts" ]]; then
                # Get packet counter.
                for (( i = 11; i < $strLen; i += 1 ))
                do
                    ch=${string:i:1}
                    if [[ "$ch" == ":" ]]; then
                        pktCnt_strStart=$(( $i + 1 ))
                        pktCnt_strLen=$(( $strLen - $pktCnt_strStart + 1 ))
                        pktCnt_str=${string:$pktCnt_strStart:$pktCnt_strLen}
                        break
                    fi
                done

                # Remove space, comma and end of string character from packet counter string.
                pktCnt=$( echo "$pktCnt_str" | sed 's/[[:blank:]]//g' | sed 's/,//g' | sed 's/[[:cntrl:]]//g' )
                #printf "[Debug] pktCnt ---> %d\n" $pktCnt

                if [[ "$pktCnt_keyStr" == "RX uc pkts" ]]; then
                    rx_arr[$portIndex]=$pktCnt
                    #printf "[Debug] rx = %d\n" ${rx_arr[$portIndex]}
                    line_index=$(( $line_index + 7 ))
                elif [[ "$pktCnt_keyStr" == "TX uc pkts" ]]; then
                    tx_arr[$portIndex]=$pktCnt
                    #printf "[Debug] tx = %d\n\n" ${tx_arr[$portIndex]}
                    line_index=$(( $line_index + 7 ))
                    portIndex_keyStr_findFlag=$FALSE
                fi
            fi
        fi
    done

    if (( $test_mode_sel == 2 )); then    # PreTest Mode
        total_pkt_num=$(( $loopback_test_pkt_num * $loopback_test_iteration ))
        for (( port_index = $port_start_index; port_index <= $port_end_index; port_index += 1 ))
        do
            if (( ${tx_arr[$port_index]} != $total_pkt_num )); then
                PKT_LOSS_FLAG=$TRUE
            elif (( ${rx_arr[$port_index]} != $total_pkt_num )); then
                PKT_LOSS_FLAG=$TRUE
            fi
        done
    fi

    printf "\n*** Show Port Packet Counter ***\n\n"
    printf "Port[Index] --- TX Counter --- RX Counter --- (TX - RX) Counter\n"
    for (( port_index = $port_start_index; port_index <= $port_end_index; port_index += 1 ))
    do
        tx_rx_diff=$(( ${tx_arr[$port_index]} - ${rx_arr[$port_index]} ))
        printf "Port[%d] --- %d --- %d --- %d\n" $(( $port_index + 1 )) ${tx_arr[$port_index]} ${rx_arr[$port_index]} $tx_rx_diff

        if (( ${tx_arr[$port_index]} == 0 )) || (( ${rx_arr[$port_index]} == 0 )); then
            PKT_LOSS_FLAG=$TRUE
        elif (( $tx_rx_diff != 0 )); then
            PKT_LOSS_FLAG=$TRUE
        fi
    done
}

function Traffic_Test_Result_Dump()
{
    test_mode_sel=$1

    if (( $test_mode_sel == $TRAFFIC_TEST_MODE_PT_PRETEST )); then
        if (( $NPS_SDK_INIT_STATUS == $FAIL )); then
            echo "===> Pre-Test Result : FAIL" | tee "$FINAL_TRAFFIC_TEST_RESULT_LOG"
        else
            if (( $LOCAL_TRAFFIC_TEST_RESULT == $PASS )); then
                echo "===> Pre-Test Result : PASS" | tee "$FINAL_TRAFFIC_TEST_RESULT_LOG"
            elif (( $LOCAL_TRAFFIC_TEST_RESULT == $FAIL )); then
                echo "===> Pre-Test Result : FAIL" | tee "$FINAL_TRAFFIC_TEST_RESULT_LOG"
            fi
        fi
    elif (( $test_mode_sel == $TRAFFIC_TEST_MODE_PT_BURNIN )); then
        if (( $NPS_SDK_INIT_STATUS == $FAIL )); then
            echo "Burn-In Test Result : FAIL" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
        else
            if (( $LOCAL_TRAFFIC_TEST_RESULT == $PASS )); then
                #echo "Burn-In Test Result : PASS" | tee "$FINAL_TRAFFIC_TEST_RESULT_LOG"
                echo "Burn-In Test Result : PASS" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
            elif (( $LOCAL_TRAFFIC_TEST_RESULT == $FAIL )); then
                #echo "Burn-In Test Result : FAIL" | tee "$FINAL_TRAFFIC_TEST_RESULT_LOG"
                echo "Burn-In Test Result : FAIL" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
            fi
        fi
    fi
}

# ======================================================================================================================================= #

### Main Function ###

if (( $tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_PRETEST )); then
    TRAFFIC_TEST_LOG_FILE_NAME="$PRETEST_LOG_FILE_NAME"

    echo "[Diag Msg] This is Nephos Pre-Test Log" >> "$TRAFFIC_TEST_LOG_FILE_NAME"
    echo "" >> "$TRAFFIC_TEST_LOG_FILE_NAME"

    sed -i "7,7d" "$DIAG_CONF_FILE_NAME"
    sed -i "7i Burn-In Set                 :   pt_loopback" "$DIAG_CONF_FILE_NAME"

    # parameters : [SFP speed], [QSFP speed], [packet count] and [iteration]
    # SFP : 25/10 ; QSFP : 100/50/40/25/10
    # EX: count 100 and iteration 5 will make total 500 packets.
    bash $MFG_SOURCE_DIR/porsche2_pretest.sh $sfp_speed $qsfp_speed $loopback_test_pkt_num $loopback_test_iteration

    sleep 3
    ./sdk_ref 2>&1 | tee "$TRAFFIC_TEST_LOG_FILE_NAME"

    sed -i "7,7d" "$DIAG_CONF_FILE_NAME"
    sed -i "7i Burn-In Set                 :   off" "$DIAG_CONF_FILE_NAME"

elif (( $tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_BURNIN )); then
    TRAFFIC_TEST_LOG_FILE_NAME="$BURNIN_LOG_FILE_NAME"

    echo "[Diag Msg] Power Cycle Round $curr_pwr_cyc_round" >> "$TRAFFIC_TEST_LOG_FILE_NAME"
    echo "           Burn-In Cycle Round $curr_burn_in_cyc_round" >> "$TRAFFIC_TEST_LOG_FILE_NAME"
    echo "           This is Nephos Traffic Test Log" >> "$TRAFFIC_TEST_LOG_FILE_NAME"
    echo "" >> "$TRAFFIC_TEST_LOG_FILE_NAME"

    # parameter : [packet trasfer time long] (min)
    bash $MFG_SOURCE_DIR/porsche2_burnin.sh $tfc_pkt_time $port_start_index $port_end_index
    sleep 3
    ./sdk_ref 2>&1 | tee "$TRAFFIC_TEST_LOG_FILE_NAME"
fi

sleep 1

if [ -f "$TRAFFIC_TEST_LOG_FILE_NAME" ]; then
    readarray log_array < "$TRAFFIC_TEST_LOG_FILE_NAME"
    log_line_num=${#log_array[@]}
    #echo "[Diag Debug] log_line_num ---> $log_line_num"

    ## for SDK init fail(PCIe bus not stable)
    for (( line = 0; line < $log_line_num; line += 1 ))
    do
        error_keyStr=${log_array[$line]:0:11}
        #echo "[Diag Debug] error_keyStr ---> $error_keyStr"
        if [[ "$error_keyStr" == "***Error***" ]]; then
            NPS_SDK_INIT_STATUS=$FAIL
            printf "\n[Diag Error Msg] Init Nephos SDK Fail !!!\n"
            #printf "Please check PCIe bus stable or not."
            break
        fi
    done

    if [[ $NPS_SDK_INIT_STATUS == $PASS ]]; then
        case $tfc_mode_sel in
            1)
                Parsing_Nephos_Port_Status
                Parsing_Nephos_Packet_Counter_For_EDVT
                ;;
            2|3)
                Parsing_Nephos_Port_Status
                Parsing_Nephos_Packet_Counter_For_PT $tfc_mode_sel

                if (( $PORT_LINK_DOWN_RETRY_OVER_FLAG == $TRUE )); then
                    echo "[Diag Error Msg] Port Link Down Fail !!!"
                    LOCAL_TRAFFIC_TEST_RESULT=$FAIL
                fi
                if (( $PKT_LOSS_FLAG == $TRUE )); then
                    echo "[Diag Error Msg] Port Counters Fail !!!"
                    LOCAL_TRAFFIC_TEST_RESULT=$FAIL
                fi
                ;;
            *)  ;;
        esac
    fi

    Traffic_Test_Result_Dump $tfc_mode_sel
else
    printf "[Diag Error Msg] Traffic Test Log NOT Exist\n"
    if (( $tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_PRETEST )); then
        echo "Pre-Test Result : Result File NOT Exist"
    elif (( $tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_BURNIN )); then
        echo "Burn-In Test Result : Result File NOT Exist" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
    fi
fi
