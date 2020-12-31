#!/bin/bash

## Purpose : This script arrange Marvell MAC run traffic test.
## History : 2019/12/10 --- Jenny modified the script

## Following are parameters definition.
{
    ## Common parameters defined
    source /home/root/mfg/mfg_sources/platform_detect.sh

    ## Traffic Test Constant Variable , value defined sync with diag-test.sh
    TRAFFIC_TEST_MODE_PT_PRETEST=2
    TRAFFIC_TEST_MODE_PT_BURNIN=3
    #TRAFFIC_TEST_MODE_FLOODING=4
    TRAFFIC_TEST_MODE_PT_4C=5

    ## Parameter for Debug
    DBG_PRINT_PARA=0
    DBG_MODE=0

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    ## Log Directory Define
    # LOG_PATH_MAC="/home/root/testLog/MAC"
    if [ ! -d "$LOG_PATH_MAC" ]; then
        mkdir "$LOG_PATH_MAC"
    fi

    FINAL_TRAFFIC_TEST_RESULT_LOG="$LOG_DIAG_TRAFFIC_RESULT_TMP"
    CYCLE_TRAFFIC_TEST_RESULT_LOG="$LOG_PATH_MAC/traffic_test_result_cycle.log"    ## for PT-4C usage

    ## ! Below 3 parameters defined value must as same as Marvell SDK defined !
    MARVELL_TRAFFIC_TEST_RESULT_LOG="$LOG_PATH_MAC/burnin_temp_log.log"
    MARVELL_PORT_STATUS_RESULT_IDENTIFY_STRING="LINK STATUS TEST RESULT: "
    MARVELL_PKT_CNT_RESULT_IDENTIFY_STRING="PACKET TEST RESULT: "

    ## Traffic Test Result Flag
    MARVELL_PORT_LINK_DOWN_RETRY_OVER_FLAG=$FALSE  # port link-down retry times flag [0:under / 1:over]
    MARVELL_PKT_LOSS_FLAG=$FALSE                   # packet loss flag [0:no / 1:yes]
    LOCAL_TRAFFIC_TEST_RESULT=$PASS
}

# ======================================================================================================================================= #

function Parsing_Marvell_Port_Status_Result
{
    #echo "[Diag Debug] Parsing Port Status"

    for (( line_index = 0; line_index <= $log_line_num; line_index += 1 ))
    do
        keyStr=${log_array[$line_index]:0:25}
        #echo "[Diag Debug] keyStr ---> $keyStr"

        if [[ "$keyStr" == "$MARVELL_PORT_STATUS_RESULT_IDENTIFY_STRING" ]]; then
            linkStatusResult_str=${log_array[$line_index]:25:4}
            #echo "[Diag Debug] linkStatusResult_str ---> $linkStatusResult_str"

            if [[ "$linkStatusResult_str" == "FAIL" ]]; then
                #echo "[Diag Debug] Traffic Test --- Port Link Down Fail"
                MARVELL_PORT_LINK_DOWN_RETRY_OVER_FLAG=$TRUE
            fi
        fi
    done
}

function Parsing_Marvell_Packet_Counter_Result
{
    #echo "[Diag Debug] Parsing Packet Counter"

    for (( line_index = 0; line_index <= $log_line_num; line_index += 1 ))
    do
        keyStr=${log_array[$line_index]:0:20}
        #echo "[Diag Debug] keyStr ---> $keyStr"

        if [[ "$keyStr" == "$MARVELL_PKT_CNT_RESULT_IDENTIFY_STRING" ]]; then
            pktCntResult_str=${log_array[$line_index]:20:4}
            #echo "[Diag Debug] pktCntResult_str ---> $pktCntResult_str"

            if [[ "$pktCntResult_str" == "FAIL" ]]; then
                #echo "[Diag Debug] Traffic Test --- Packet Loss Fail"
                MARVELL_PKT_LOSS_FLAG=$TRUE
            fi
        fi
    done
}

function Traffic_Test_Result_Dump
{
    if (( $LOCAL_TRAFFIC_TEST_RESULT == $PASS )); then
        if (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_PRETEST )); then
            echo "Traffic Test Result : PASS" | tee "$FINAL_TRAFFIC_TEST_RESULT_LOG"
        elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_BURNIN )); then
            echo "Traffic Test Result : PASS" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
        elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_4C )); then
            echo "Round $this_round Traffic Test Result : PASS" >> "$CYCLE_TRAFFIC_TEST_RESULT_LOG"
        fi
    elif (( $LOCAL_TRAFFIC_TEST_RESULT == $FAIL )); then
        if (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_PRETEST )); then
            echo "Traffic Test Result : FAIL" | tee "$FINAL_TRAFFIC_TEST_RESULT_LOG"
        elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_BURNIN )); then
            echo "Traffic Test Result : FAIL" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
        elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_4C )); then
            echo "Round $this_round Traffic Test Result : FAIL" >> "$CYCLE_TRAFFIC_TEST_RESULT_LOG"
        fi
    fi
}

function Only_Parse_Log
{
    this_cycle=$1

    if [ ! -z "$2" ]; then
        this_round=$2
        echo " [Diag Msg] Waiting Parsing Cycle $this_cycle - Round $this_round Traffic Test Log ..."
    else
        echo " [Diag Msg] Waiting Parsing Traffic Test Log ..."
    fi

    readarray log_array < "$MARVELL_TRAFFIC_TEST_RESULT_LOG"
    log_line_num=${#log_array[@]}
    #echo "[Debug] log_line_num ---> $log_line_num"

    Parsing_Marvell_Port_Status_Result
    Parsing_Marvell_Packet_Counter_Result

    if (( $MARVELL_PORT_LINK_DOWN_RETRY_OVER_FLAG == $TRUE )) || (( $MARVELL_PKT_LOSS_FLAG == $TRUE )); then
        LOCAL_TRAFFIC_TEST_RESULT=$FAIL
    fi

    Traffic_Test_Result_Dump
    sleep 1

    echo " [Diag Msg] Parsing Traffic Test Log ... Done"

    ## Rename Current Round Log File Name
    if (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_4C )); then
        mv "$MARVELL_TRAFFIC_TEST_RESULT_LOG" "${LOG_PATH_MAC}/traffic_test_${this_cycle}_${this_round}.log"
    else
        mv "$MARVELL_TRAFFIC_TEST_RESULT_LOG" "${LOG_PATH_MAC}/traffic_test_${this_cycle}.log"
    fi
    usleep 30000
}

# ======================================================================================================================================= #

### Main Function ###

# 20200828 add parsing log case for PT 4C test.
if (( $# == 2 ));then
    para_tfc_mode_sel=$TRAFFIC_TEST_MODE_PT_4C
    Only_Parse_Log $1 $2
    exit 1
fi

## Parameter for Internal Traffic Test
para_tfc_mode_sel=${1:-"3"}
shift 1
if (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_PRETEST )); then
    para_tfc_qsfp_sp=${1:-"100"}
    para_tfc_sfp_sp=${2:-"25"}
    para_loopback_test_pkt_num=${3:-"100"}
    shift 3
elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_BURNIN )); then
    curr_pwr_cyc_round=${1:-"1"}
    para_tfc_pkt_time=${2:-"1"}
    para_tfc_if=${3:-"lbm"}
    shift 3
elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_4C )); then
    curr_pwr_cyc_round=${1:-"1"}
    para_tfc_pkt_time=${2:-"1"}
    para_tfc_if=${3:-"lbm"}
    para_tfc_cycle=${4:-"1"}
    shift 4
fi

if (( $DBG_PRINT_PARA == $TRUE )); then
    echo ""
    echo "{ Traffic Test Parameters }"
    echo " para_tfc_mode_sel   ---> $para_tfc_mode_sel"
    if (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_PRETEST )); then
        echo " para_tfc_sfp_sp     ---> $para_tfc_sfp_sp"
        echo " para_tfc_qsfp_sp    ---> $para_tfc_qsfp_sp"
        echo " para_loopback_test_pkt_num   ---> $para_loopback_test_pkt_num"
        echo ""
    elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_BURNIN )); then
        echo " curr_pwr_cyc_round  ---> $curr_pwr_cyc_round"
        echo " para_tfc_pkt_time   ---> $para_tfc_pkt_time (min)"
        echo " para_tfc_if         ---> $para_tfc_if"
    elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_4C )); then
        echo " curr_pwr_cyc_round  ---> $curr_pwr_cyc_round"
        echo " para_tfc_pkt_time   ---> $para_tfc_pkt_time (min)"
        echo " para_tfc_if         ---> $para_tfc_if"
        echo " para_tfc_cycle      ---> $para_tfc_cycle"
    fi
    echo ""
fi

# --------------------------------------------------------------------------------------------------------------------------------------- #

if (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_PRETEST )); then
    echo "[Diag Msg] Run PreTest Mode"
    bash $MFG_SOURCE_DIR/gemini_pretest.sh sfp=$para_tfc_sfp_sp qsfp=$para_tfc_qsfp_sp packet=$para_loopback_test_pkt_num
elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_BURNIN )); then
    echo "[Diag Msg] Run BurnIn Mode"
    marvell_tfc_pkt_time=$(( $para_tfc_pkt_time * 60 )) # convert time unit minute to second
    bash $MFG_SOURCE_DIR/gemini_burnin.sh seconds=$marvell_tfc_pkt_time if=$para_tfc_if tfc-cycle=$curr_pwr_cyc_round

    ## Enter Marvell SDK.
    # $MFG_WORK_DIR/appDemo   (called in script)
    sleep 3

    ## Parsing Marvell Log
    if [ -f "$MARVELL_TRAFFIC_TEST_RESULT_LOG" ]; then
        Only_Parse_Log ${curr_pwr_cyc_round}
    else
        printf "[Diag Error Msg] Traffic Test Log NOT Exist\n"
        echo "Traffic Test Result : Result File NOT Exist" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
    fi

    mv "${LOG_PATH_MAC}/sdk_init.log" "${LOG_PATH_MAC}/sdk_init_${curr_pwr_cyc_round}.log"
    sync
elif (( $para_tfc_mode_sel == $TRAFFIC_TEST_MODE_PT_4C )); then
    echo "[Diag Msg] Run PT 4C Mode"
    marvell_tfc_pkt_time=$(( $para_tfc_pkt_time * 60 )) # convert time unit minute to second
    bash $MFG_SOURCE_DIR/gemini_burnin.sh seconds=$marvell_tfc_pkt_time if=$para_tfc_if tfc-mode=6 tfc-cycle=$curr_pwr_cyc_round tfc-round=$para_tfc_cycle    ## tfc-mode '6' is defined same in SDK.

    sleep 3

    ## parsing all rounds' result and then result to last file to light SYSLED
    check_final_result=$( { grep -n "FAIL" "$CYCLE_TRAFFIC_TEST_RESULT_LOG" ; } 2>&1 )
    if [ ! -z "$check_final_result" ]; then
        echo "Traffic Test Result : FAIL" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
    else
        echo "Traffic Test Result : PASS" > "$FINAL_TRAFFIC_TEST_RESULT_LOG"
    fi
    mv "$CYCLE_TRAFFIC_TEST_RESULT_LOG" "${LOG_PATH_MAC}/traffic_test_result_cycle_${curr_pwr_cyc_round}.log"

    mv "${LOG_PATH_MAC}/sdk_init.log" "${LOG_PATH_MAC}/sdk_init_${curr_pwr_cyc_round}.log"
    sync
fi
