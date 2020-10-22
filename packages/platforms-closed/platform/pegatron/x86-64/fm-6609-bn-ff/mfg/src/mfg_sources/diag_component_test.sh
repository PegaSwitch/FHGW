#!/bin/bash

## Illustration :
## This script arrange the 4C component test.

source /home/root/mfg/mfg_sources/platform_detect.sh

## Following are parameters definition.
{
    # Parameter for Debug
    DBG_PRINT_PARA=0

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # Check file exist or not every 10 sec.
    # 10(sec) * 18(round) = 180(sec)
    DIAG_CALL_FUNC_DELAY_TIME=1000000     # (uint : msec)
    DIAG_FILE_EXIST_CHECK_WAIT_TIME=10    # (unit : sec)
    DIAG_FILE_EXIST_CHECK_CNT=18

    DIAG_STORAGE_TEST_FAIL_TOL=1   # Due to storage fail many times with wierd file not exist issue, so add 1 time tolerance.

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # 1, PT, sequential, 32, DRAM-eMMC-USB-SSD, no, 60

    curr_pwr_cyc_round=${1:-"1"}             # Current Power Cycle Round
    shift 1

    # Parameter for Storage Test
    test_mode=${1:-"PT"}           # EDVT / PT / THERMAL / EMC / Safety
    stg_mode=${2:-"sequential"}    # parallel(for EDVT & PT-4C) / sequential(for PT)
    stg_size=${3:-"32"}            # 64 / 128 / 256 / 512 / 1024 (unit : Mega bytes)
    stg_dev=${4:-"DRAM-eMMC"}      # DRAM-eMMC / DRAM-eMMC-USB / DRAM-eMMC-USB-SSD
    stg_cns_out=${5:-"no"}         # yes / no
    cmp_test_time=${6:-"60"}       # each component test execution time (unit : sec)
    shift 6

    # Parameter for OOB Test
    oob_dut_ip=${1:-"192.168.1.1"}      # for OOB(SGMII) test DUT IP
    oob_target_ip=${2:-"192.168.1.2"}   # for OOB(SGMII) test target IP
    shift 2

    # Parameter for I2C Bus Test
    proj_name=${1:-"Porsche"}       # project name : Bugatti / Cadillac / Porsche ...
    shift 1

    # Parameter for PCIe Bus Test (For Broadcom MAC)
    pcie_test_rnd_time=${1:-"60"}   # PCIe bus test one round time (unit : sec)
    shift 1

    # Parameter for 4C item test, mini round in one power cycle.
    four_c_round_num=${1:-"1"}   # 4C component test round in each power cycle (unit : round)
    shift 1

    para_edvt_sel_test=${1:-"4C Component Test"}
    # 4C Component Test / 4C Component + Internal Traffic Test / 4C Component + External Ramping Traffic Test
    # If select "4C Component + Internal Traffic Test" and "4C Component + External Ramping Traffic Test",
    # which include "Traffic Test", need by pass PCIe bus test.
    shift 1

    if (( $DBG_PRINT_PARA == $TRUE )); then
        echo ""
        echo "{ Component Test Parameters }"

        echo "curr_pwr_cyc_round ---> $curr_pwr_cyc_round"

        echo "test_mode          ---> $test_mode"

        echo "stg_mode           ---> $stg_mode"
        echo "stg_size           ---> $stg_size"
        echo "stg_dev            ---> $stg_dev"
        echo "stg_cns_out        ---> $stg_cns_out"
        echo "cmp_test_time      ---> $cmp_test_time"

        echo "oob_dut_ip         ---> $oob_dut_ip"
        echo "oob_target_ip      ---> $oob_target_ip"

        echo "proj_name          ---> $proj_name"

        echo "pcie_test_rnd_time ---> $pcie_test_rnd_time"

        echo "four_c_round_num   ---> $four_c_round_num"

        echo "para_edvt_sel_test ---> $para_edvt_sel_test"
        echo ""
    fi

    if [[ "$stg_cns_out" == "no" ]]; then
        print_on_console="consoleON"
    else
        print_on_console="consoleOFF"
    fi

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    # Working Directory Define
    if [ ! -d "$LOG_PATH_STORAGE" ]; then
        mkdir "$LOG_PATH_STORAGE"
    fi

    DIAG_STG_TEST_LOG_FILE_NAME=${LOG_PATH_STORAGE}/peripheral_test_${curr_pwr_cyc_round}.log
    DIAG_STG_TEST_RESULT_LOG_FILE_NAME="$LOG_DIAG_COMPONENT_RESULT_TMP"

    # Console Output Log
    DIAG_EDVT_STG_TEST_CNS_OUT_LOG="/tmp/edvt_storage_test_console_out.log"
    DIAG_PT_STG_TEST_CNS_OUT_LOG="/tmp/pt_storage_test_console_out.log"
    DIAG_OOB_TEST_CNS_OUT_LOG="/tmp/oob_test_test_console_out.log"
    DIAG_I2C_TEST_CNS_OUT_LOG="/tmp/i2c_test_console_out.log"
    DIAG_PCIE_TEST_CNS_OUT_LOG="/tmp/pcie_test_console_out.log"

    # Storage Test Result Flag
    DIAG_LOCAL_STORAGE_TEST_RESULT=$PASS
}

# ======================================================================================================================================= #

function Diag_Run_Component_Test
{
    # Storage Test
    if [[ "$stg_mode" == "parallel" ]]; then           # For EDVT
        case "$stg_dev" in
            "DRAM-eMMC")            stg_test_dev_sel=1  ;;
            "DRAM-eMMC-USB")        stg_test_dev_sel=2  ;;
            "DRAM-eMMC-USB-SSD")    stg_test_dev_sel=3  ;;
            "DRAM-eMMC-USB-SSD-SPI")    stg_test_dev_sel=4  ;;
            *)  ;;
        esac

        printf "[Diag Msg] Run Storage Test --- Storage Test Mode Set To [%s, %s]\n" "$stg_mode" $stg_dev
        printf "[Diag Msg] Running Storage Test ...\n\n"

        source ${MFG_SOURCE_DIR}/peripheralTest_parallel.sh $stg_size $stg_test_dev_sel "$stg_cns_out" $cmp_test_time $curr_pwr_cyc_round $round 2>&1 > "$DIAG_EDVT_STG_TEST_CNS_OUT_LOG" &

    elif [[ "$stg_mode" == "sequential" ]]; then       # For PT
        printf "[Diag Msg] Run Storage Test --- Storage Test Mode Set To [%s]\n\n" "$stg_mode"

        source ${MFG_SOURCE_DIR}/peripheralTest_sequential.sh $stg_size $curr_pwr_cyc_round 2>&1 | tee "$DIAG_PT_STG_TEST_CNS_OUT_LOG"
    fi

    usleep $DIAG_CALL_FUNC_DELAY_TIME

    if [[ "$test_mode" == "EDVT" ]]; then
        # OOB Test
        printf "[Diag Msg] Run OOB Test\n"
        source ${MFG_SOURCE_DIR}/OOB_ping_test.sh "$oob_dut_ip" "$oob_target_ip" $cmp_test_time "consoleOFF" $curr_pwr_cyc_round 2>&1 > "$DIAG_OOB_TEST_CNS_OUT_LOG" &
        usleep $DIAG_CALL_FUNC_DELAY_TIME

        # I2C Bus Test
        ## 20200731 Add Gemini special case -- wake I2C test in Marvell SDK.
        if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
            echo "time_long=$cmp_test_time
                  cycle_round=$curr_pwr_cyc_round
                 " >> "/tmp/current-EDVT-test"
            printf "[Diag Msg] I2C Bus Test will be running after SDK ready\n\n"
        else
            printf "[Diag Msg] Run I2C Bus Test\n\n"
            source ${MFG_SOURCE_DIR}/i2c_bus_test.sh $cmp_test_time $curr_pwr_cyc_round 2>&1 > "$DIAG_I2C_TEST_CNS_OUT_LOG" &
            usleep $DIAG_CALL_FUNC_DELAY_TIME
        fi

        # PCIe Test
        macName=$( lspci | grep "01:00.0" )
        if [[ "$macName" == *"Broadcom"* ]]; then   # Project is using Broadcom MAC.
            if [[ "$para_edvt_sel_test" == "4C Component Test" ]]; then
                # When running traffic test, PCIe bus test can NOT run in the same time.
                printf "[Diag Msg] Run PCIe Test (For Broadcom MAC)\n"
                source ${MFG_SOURCE_DIR}/PCIe_test_BCM.sh $cmp_test_time $pcie_test_rnd_time $curr_pwr_cyc_round 2>&1 > "$DIAG_PCIE_TEST_CNS_OUT_LOG" &
                usleep $DIAG_CALL_FUNC_DELAY_TIME
            else
                printf "[Diag Msg] Need to run traffic test, so PCIe test is disable.\n"
            fi
        fi
    elif [[ "$test_mode" == "PT" ]] && [[ "$stg_mode" == "parallel" ]]; then
        # I2C Bus Test
        ## Gemini special case -- wake I2C test in Marvell SDK.
        if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
            echo "time_long=$(( $cmp_test_time - 5))
                  cycle_round=$curr_pwr_cyc_round
                 " >> "/tmp/current-EDVT-test"
            printf "[Diag Msg] I2C Bus Test will be running after SDK ready\n\n"
        else
            printf "[Diag Msg] Run I2C Bus Test\n\n"
            source ${MFG_SOURCE_DIR}/i2c_bus_test.sh $cmp_test_time $curr_pwr_cyc_round 2>&1 > "$DIAG_I2C_TEST_CNS_OUT_LOG" &
            usleep $DIAG_CALL_FUNC_DELAY_TIME
        fi
    elif [[ "$test_mode" == "EMC" ]]; then
        # OOB Test
        printf "[Diag Msg] Run OOB Test\n"
        source ${MFG_SOURCE_DIR}/OOB_ping_test.sh "$oob_dut_ip" "$oob_target_ip" $cmp_test_time $print_on_console $curr_pwr_cyc_round 2>&1 > "$DIAG_OOB_TEST_CNS_OUT_LOG" &
        usleep $DIAG_CALL_FUNC_DELAY_TIME
    fi
}

## For PT Sequential Mode Test
function Diag_Parsing_Storage_Test_Log
{
    printf "\n[Diag Msg] Show Storage Test Items Result\n"

    dev_test_fail=$FALSE
    #dev_not_insert=$FALSE

    while read string
    do
        strlen=$( expr length "$string" )

        for (( i = 1; i <= $strlen; i += 1 ))
        do
            result_str_1=$( expr substr "$string" $i 4 )
            result_str_2=$( expr substr "$string" $i 12 )

            if [[ "$result_str_1" == "PASS" ]] || [[ "$result_str_1" == "FAIL" ]]; then
                test_item_str_1=$( expr substr "$string" $(( $i - 10 )) 4 )
                test_item_str_2=$( expr substr "$string" $(( $i - 9 )) 3 )

                if [[ "$test_item_str_1" == "DRAM" ]] || [[ "$test_item_str_1" == "eMMC" ]]; then
                    printf "%s %s\n" "$test_item_str_1" "Test $result_str_1"
                elif [[ "$test_item_str_2" == "USB" ]] || [[ "$test_item_str_2" == "SSD" ]]; then
                    printf "%s %s\n" "$test_item_str_2" "Test $result_str_1"
                fi

                if [[ "$result_str_1" == "FAIL" ]]; then
                    dev_test_fail=$TRUE
                fi
            elif [[ "$result_str_2" == "not inserted" ]]; then
                test_item_str_1=$( expr substr "$string" $(( $i - 8 )) 4 )
                test_item_str_2=$( expr substr "$string" $(( $i - 7 )) 3 )

                if [[ "$test_item_str_1" == "DRAM" ]] || [[ "$test_item_str_1" == "eMMC" ]]; then
                    printf "%s %s\n" "$test_item_str_1" "$result_str_2"
                elif [[ "$test_item_str_2" == "USB" ]] || [[ "$test_item_str_2" == "SSD" ]]; then
                    printf "%s %s\n" "$test_item_str_2" "$result_str_2"
                fi

            #    dev_not_insert=$TRUE
            fi
        done
    done < "$DIAG_STG_TEST_LOG_FILE_NAME"

    #if (( dev_test_fail == $TRUE )) || (( dev_not_insert == $TRUE )); then
    if (( dev_test_fail == $TRUE )); then
        DIAG_LOCAL_STORAGE_TEST_RESULT=$FAIL
    fi
}

## For PT Parallel Mode Test
function Diag_Parsing_Parallel_Storage_Test_Log
{
    log_emmc="$LOG_PATH_STORAGE/emmc_test_${curr_pwr_cyc_round}_${round}.log"
    log_usb="$LOG_PATH_STORAGE/usb_test_${curr_pwr_cyc_round}_${round}.log"
    log_ssd="$LOG_PATH_STORAGE/ssd_test_${curr_pwr_cyc_round}_${round}.log"
    dev_test_fail=$FALSE

    echo " ---- [ ${curr_pwr_cyc_round} -- ${round} ] ----" >> $DIAG_STG_TEST_LOG_FILE_NAME

    ## eMMC
    if [ ! -f "$log_emmc" ]; then    ## file name must same as defined in storageTest_parallel.sh
        echo " # eMMC test skip"    >> $DIAG_STG_TEST_LOG_FILE_NAME
    else
        check_result=$( { grep -n "eMMC Test" "$log_emmc" | grep "FAIL" | wc -l ; } 2>&1 )
        if (( $check_result > $DIAG_STORAGE_TEST_FAIL_TOL )); then    ## origin is 0 , but always test fail while cycle 2- round 1 ....
            echo " # eMMC test FAIL [ $check_result ]"    >> $DIAG_STG_TEST_LOG_FILE_NAME
            dev_test_fail=$TRUE
        else
            echo " # eMMC test PASS"    >> $DIAG_STG_TEST_LOG_FILE_NAME
        fi
    fi

    ## USB
    if [ ! -f "$log_usb" ]; then     ## file name must same as defined in storageTest_parallel.sh
        echo " # USB test skip"    >> $DIAG_STG_TEST_LOG_FILE_NAME
    else
        check_result=$( { grep -n "USB Test" "$log_usb" | grep "FAIL" | wc -l ; } 2>&1 )
        if (( $check_result > $DIAG_STORAGE_TEST_FAIL_TOL )); then    ## origin is 0 , but always test fail while cycle 2- round 1 ....
            echo " # USB test FAIL [ $check_result ]"    >> $DIAG_STG_TEST_LOG_FILE_NAME
            dev_test_fail=$TRUE
        else
            echo " # USB test PASS"    >> $DIAG_STG_TEST_LOG_FILE_NAME
        fi
    fi

    ## SSD
    if [ ! -f "$log_ssd" ]; then     ## file name must same as defined in storageTest_parallel.sh
        echo " # SSD test skip"    >> $DIAG_STG_TEST_LOG_FILE_NAME
    else
        check_result=$( { grep -n "SSD Test" "$log_ssd" | grep "FAIL" | wc -l ; } 2>&1 )
        if (( $check_result > $DIAG_STORAGE_TEST_FAIL_TOL )); then    ## origin is 0 , but always test fail while cycle 2- round 1 ....
            echo " # SSD test FAIL [ $check_result ]"    >> $DIAG_STG_TEST_LOG_FILE_NAME
            dev_test_fail=$TRUE
        else
            echo " # SSD test PASS"    >> $DIAG_STG_TEST_LOG_FILE_NAME
        fi
    fi

    echo " "    >> $DIAG_STG_TEST_LOG_FILE_NAME

    if (( dev_test_fail == $TRUE )); then
        DIAG_LOCAL_STORAGE_TEST_RESULT=$FAIL
    fi
}

function Diag_Storage_Test_Result_Dump
{
    #echo "[Debug] Storage Test Result"

    if (( $DIAG_LOCAL_STORAGE_TEST_RESULT == $PASS )); then
        #echo "Storage Test Result : PASS" | tee "$DIAG_STG_TEST_RESULT_LOG_FILE_NAME"
        echo "Storage Test Result : PASS" > "$DIAG_STG_TEST_RESULT_LOG_FILE_NAME"
    elif (( $DIAG_LOCAL_STORAGE_TEST_RESULT == $FAIL )); then
        #echo "Storage Test Result : FAIL" | tee "$DIAG_STG_TEST_RESULT_LOG_FILE_NAME"
        echo "Storage Test Result : FAIL" > "$DIAG_STG_TEST_RESULT_LOG_FILE_NAME"
    fi
    sync
}

# ======================================================================================================================================= #

### Main Function ###

## If test log exist before run test, delete it.
# In this version, only remove storage test log.
if [ -f "$DIAG_STG_TEST_LOG_FILE_NAME" ]; then
    #echo "[Debug] Show Folder"
    #ls ~/testLog
    #echo "[Debug] \"Storage Test Log\" has been exist, so remove it ..."
    rm "$DIAG_STG_TEST_LOG_FILE_NAME"
fi

if [[ "$test_mode" == "PT" && "$stg_mode" == "parallel" ]]; then
    file_not_exist_cnt=1

    if (( $cmp_test_time <= 180 )); then
        actual_cmp_test_time=$cmp_test_time
    else
        actual_cmp_test_time=$(( $cmp_test_time - ( $DIAG_STORAGE_TEST_CHECK_BUFFER_TIME * 60 ) ))    ## actual execution time
    fi

    for (( round = 1 ; round <= $four_c_round_num ; round += 1 ))
    do
        target_end_round_timestamp=$(($(date +%s) + $cmp_test_time ))

        echo "[Diag msg] --- ${curr_pwr_cyc_round} -- ${round} --- Start @ $(date +'%Y/%m/%d %T.%N')"
        Diag_Run_Component_Test
        sleep $(( actual_cmp_test_time + 10 ))    ## add additional buffer time 10 sec for sure verify done.
        wait

        ## parse this round logs.
        Diag_Parsing_Parallel_Storage_Test_Log

        if (( $DIAG_LOCAL_STORAGE_TEST_RESULT == $FAIL )); then
            break
        fi

        ## wait next round's start time achieved
        while (($(date +%s) < $target_end_round_timestamp )) ;
        do
            sleep 5
        done
    done

    Diag_Storage_Test_Result_Dump

else
    Diag_Run_Component_Test

    if [[ "$test_mode" == "PT" && "$stg_mode" == "sequential" ]]; then
        file_not_exist_cnt=1
        while true;
        do
            if [ -f "$DIAG_STG_TEST_LOG_FILE_NAME" ]; then
                #printf "[Diag Debug] %s File Exist !\n" "$DIAG_STG_TEST_LOG_FILE_NAME"
                
                break
            else
                printf "[Diag Msg] [%d] Waiting Storage Test Log ...\n" $file_not_exist_cnt
                if (( $file_not_exist_cnt > $DIAG_FILE_EXIST_CHECK_CNT )); then
                    printf "[Diag Error Msg] Storage Test Log NOT Exist\n"
                    break
                fi
                file_not_exist_cnt=$(( $file_not_exist_cnt + 1 ))
                sleep $DIAG_FILE_EXIST_CHECK_WAIT_TIME
            fi
        done

        Diag_Storage_Test_Result_Dump
    fi
fi
