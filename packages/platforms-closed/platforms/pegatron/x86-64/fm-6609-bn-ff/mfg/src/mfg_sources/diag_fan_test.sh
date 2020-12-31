#!/bin/bash

## Following are parameters definition.
{
    source /home/root/mfg/mfg_sources/platform_detect.sh

    ## Parameter for Debug
    DBG_FAN_TEST=0
    DBG_PRINT_PARA=0
    DBG_PRINT_FAN_RPM=1
    DBG_PRINT_FAN_TEST_RESULT=1

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    curr_pwr_cyc_round=${1:-"1"}  # Current Power Cycle Round
    proj_name=${2:-"Gemini"}     # Current Test Project Name
    shift 2

    ## Fan RPM Tolerance Setting
    ## fan_pwm_bkp : if current testing fan PWM less/more than this fan PWM setting
    ##               use following low/high speed fan RPM tolerance range
    fan_pwm_bkp=${1:-"10"}
    fan_hspd_rpm_tlr=${2:-"15"}    # User High Speed Fan RPM Tolerance (unit : percent)
    fan_lspd_rpm_tlr=${3:-"0x8c"}   # User Low Speed Fan RPM Tolerance  (unit : r.p.m)
    shift 3

    if (( $DBG_PRINT_PARA == $TRUE )); then
        echo ""
        echo "{ Fan Test Parameters }"

        echo "curr_pwr_cyc_round ---> $curr_pwr_cyc_round"
        echo "proj_name          ---> $proj_name"

        echo "fan_pwm_bkp        ---> $fan_pwm_bkp"
        echo "fan_hspd_rpm_tlr   ---> $fan_hspd_rpm_tlr"
        echo "fan_lspd_rpm_tlr   ---> $fan_lspd_rpm_tlr"
        echo ""
    fi

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    ## Working Directory Define
    if [ ! -d "$LOG_PATH_FAN" ]; then
        mkdir "$LOG_PATH_FAN"
    fi

    ## File Path Define
    DIAG_FAN_TEST_LOG_FILE_NAME=$LOG_PATH_FAN/fan_test_$curr_pwr_cyc_round.log
    DIAG_FAN_TEST_RESULT_LOG_FILE_NAME="$LOG_DIAG_FAN_RESULT_TMP"

    ## Fan Test Result Flag
    DIAG_LOCAL_FAN_TEST_RESULT=$PASS

    # --------------------------------------------------------------------------------------------------------------------------------------- #

    ## FanBoard Related Define (some in platform_detect.sh)
    MB_MCU_SMARTFAN_DISABLE=0x0
    MB_MCU_SMARTFAN_ENABLE=0x1
    MB_MCU_SMARTFAN_TUNE_Y=0x1
    MB_MCU_SMARTFAN_TUNE_N=0x0
    MB_MCU_FAN_PWM_BP_SET_REG=0x1B
    MB_MCU_FAN_LSPD_RPM_TOL_REG=0x1C
    MB_MCU_FAN_HSPD_RPM_TOL_REG=0x1D
    MB_MCU_FAN_ALERT_MODE_KEEP=0x0    ## read on clear
    MB_MCU_FAN_ALERT_MODE_AUTO=0x1

    ## Fan Test Constant Variable
    INNER_FAN_SEL=1
    OUTER_FAN_SEL=2

    ## Fan Inner/Outer RPM Standard
    FAN_HIGH_SPEED_INNER_RPM_STD=23000
    FAN_LOW_SPEED_INNER_RPM_STD=2300
    FAN_HIGH_SPEED_OUTER_RPM_STD=22500
    FAN_LOW_SPEED_OUTER_RPM_STD=2250

    ## High / Mediun / Low Fan PWM For Fan Testing
    if (( $DBG_FAN_TEST == $FALSE )); then
        FAN_TEST_HIGH_SPEED=100
        #FAN_TEST_MEDIUM_SPEED=50
        FAN_TEST_LOW_SPEED=0
    else
        FAN_TEST_HIGH_SPEED=0
        FAN_TEST_LOW_SPEED=20
    fi
    FAN_TEST_RETRY_TIMES=3
    WAIT_FAN_RPM_STABLE_TIME=15    ## wait fan RPM stable time (unit:sec)
    FAN_TEST_RETRY_DELAY_TIME=12   ## delay time between 2 retry round (unit:sec)

}

# ======================================================================================================================================= #

function Write_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3
    i2c_data=$4

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cset -y $i2c_bus $i2c_device $i2c_register $i2c_data
    else
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_SET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE $i2c_data ; } 2>&1 )
    fi
    usleep $I2C_ACTION_DELAY
}

function Read_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register
        usleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE ; } 2>&1 )
        usleep $I2C_ACTION_DELAY
        ## 20200921 Due to BMC v3 will return fail msg, so need to add case to handle
        if [[ "$value_get_through_ipmi" == *"Unspecified error"* ]]; then
            ipmi_value_toHex=0x00
        else
            ipmi_value_toHex=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 2)))" ; } 2>&1 )    # orig value format is " XX" , so just get XX then transform as 0xXX format.
        fi
        echo $ipmi_value_toHex    # this line is to make return with value 0xXX
        return
    fi
}

function Read_I2C_Device_Node_Word()      ## read as word.
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register w
        usleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_TWO ; } 2>&1 )
        #echo $value_get_through_ipmi    # for debug, value format is " XX XX"
        usleep $I2C_ACTION_DELAY
        ## 20200921 Due to BMC v3 will return fail msg, so need to add case to handle
        if [[ "$value_get_through_ipmi" == *"Unspecified error"* ]]; then
            appendBothByte=0x0000
        else
            firstByte=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 5 3)))" ; } 2>&1 )
            secondByte=$( { printf '%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 3)))" ; } 2>&1 )
            appendBothByte=$( echo $firstByte$secondByte )
        fi
        echo $appendBothByte
        return
    fi
}

function Write_Fan_Test_Setting()
{
    ## Switch I2C MUX to MainBoard MCU
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU

    ## Set SmartFan "disable"(manual mode)
    # i2cset -y 0 0x70 0x11 0x0
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_ENABLE_BASE_REG $MB_MCU_SMARTFAN_DISABLE

    ## 20200205 Due to these projects use old MCU FW.
    if [[ "$PROJECT_NAME" != "PORSCHE" ]] && [[ "$PROJECT_NAME" != "MERCEDES" ]]; then
        ## Enable Setting Fan RPM Tolerance Register
        #i2cset -y 0 0x70 0x12 0x1
        Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_TUNE_REG $MB_MCU_SMARTFAN_TUNE_Y

        ## Set Fan PWM Breakpoint to Register
        #i2cset -y 0 0x70 0x1B $fan_pwm_bkp
        Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_PWM_BP_SET_REG $fan_pwm_bkp

        ## Set Low/High Speed Fan RPM Tolerance Range to Register
        #i2cset -y 0 0x70 0x1C $fan_lspd_rpm_tlr
        Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_LSPD_RPM_TOL_REG $fan_lspd_rpm_tlr

        #i2cset -y 0 0x70 0x1D $fan_hspd_rpm_tlr
        Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_HSPD_RPM_TOL_REG $fan_hspd_rpm_tlr

        ## Disable Setting Fan RPM Tolerance Register
        #i2cset -y 0 0x70 0x12 0x0
        Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_TUNE_REG $MB_MCU_SMARTFAN_TUNE_N
    fi

    ## Set MainBoard MCU alert register to "keep" mode(read on clear)
    # i2cset -y 0 0x70 0x59 0x0
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_ALERT_MODE_REG $MB_MCU_FAN_ALERT_MODE_KEEP
}

function Read_Fan_Test_Setting()
{
    reg_fan_pwm_bkp=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_PWM_BP_SET_REG; } 2>&1 )

    # Because OLD fan board MCU code NOT record +-500(r.p.m) this special case,
    # (MCU only record value which unit is percent)
    # do NOT get setting value from MCU register.
    ## 20200205 Due to these projects use old MCU FW.
    if [[ "$PROJECT_NAME" == "PORSCHE" ]] || [[ "$PROJECT_NAME" == "MERCEDES" ]]; then
        fan_lspd_rpm_tlr=500    # (unit:r.p.m)
    else
        read_out_lspd_rpm_tol=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_LSPD_RPM_TOL_REG; } 2>&1 )
        fan_lspd_rpm_tlr=$(( 100 + 10 * ( $((read_out_lspd_rpm_tol)) - 100) ))
        usleep $I2C_ACTION_DELAY
    fi

    reg_fan_hspd_rpm_tlr=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_HSPD_RPM_TOL_REG; } 2>&1 )
}

function Get_Fan_RPM_Tolerance_Range()
{
    fan_pwm=$1

    ## Use High / Low Speed Fan RPM Tolerance Range
    high_spd_rpm_tlr_range=$( echo "scale=3; $fan_hspd_rpm_tlr / 100" | bc )
    low_spd_rpm_tlr_range=$fan_lspd_rpm_tlr
    #low_spd_rpm_tlr_range=$(  echo "scale=3; $fan_lspd_rpm_tlr / 100" | bc )
    #printf "high_spd_rpm_tlr_range : %.3f\n" $high_spd_rpm_tlr_range
    #printf "low_spd_rpm_tlr_range  : %.3f\n" $low_spd_rpm_tlr_range

    # ---------------------------------------------------------------------------------------------------------------------------------- #

    duty_cycle=$( echo "scale=2; $fan_pwm / 100" | bc )
    if (( $fan_pwm > $fan_pwm_bkp )); then
        FAN_HIGH_SPEED_INNER_RPM_STD=23000
        FAN_LOW_SPEED_INNER_RPM_STD=5650
        FAN_HIGH_SPEED_OUTER_RPM_STD=22500
        FAN_LOW_SPEED_OUTER_RPM_STD=5500

        duty_cycle_diff=$( echo "scale=3; ($duty_cycle - 0.2)" | bc )
        high_low_duty_cycle_diff=$( echo "scale=3; (1 - 0.2)" | bc )
    else
        FAN_HIGH_SPEED_INNER_RPM_STD=3350
        FAN_LOW_SPEED_INNER_RPM_STD=2300
        FAN_HIGH_SPEED_OUTER_RPM_STD=3300
        FAN_LOW_SPEED_OUTER_RPM_STD=2250

        duty_cycle_diff=$( echo "scale=3; ($duty_cycle - 0)" | bc )
        high_low_duty_cycle_diff=$( echo "scale=3; (0.1 - 0)" | bc )
    fi

    fan_in_rpm_std=$(  echo "scale=3; (($FAN_HIGH_SPEED_INNER_RPM_STD - $FAN_LOW_SPEED_INNER_RPM_STD) * $duty_cycle_diff + $FAN_LOW_SPEED_INNER_RPM_STD * $high_low_duty_cycle_diff) / $high_low_duty_cycle_diff" | bc )
    fan_out_rpm_std=$( echo "scale=3; (($FAN_HIGH_SPEED_OUTER_RPM_STD - $FAN_LOW_SPEED_OUTER_RPM_STD) * $duty_cycle_diff + $FAN_LOW_SPEED_OUTER_RPM_STD * $high_low_duty_cycle_diff) / $high_low_duty_cycle_diff" | bc )

    if (( $fan_pwm > $fan_pwm_bkp )); then
        fan_rpm_over_tlr=$(  echo "scale=3; (1 + $high_spd_rpm_tlr_range)" | bc )
        fan_rpm_under_tlr=$( echo "scale=3; (1 - $high_spd_rpm_tlr_range)" | bc )

        fan_in_rpm_over=$(   echo "scale=3; $fan_in_rpm_std * $fan_rpm_over_tlr"  | bc )
        fan_in_rpm_under=$(  echo "scale=3; $fan_in_rpm_std * $fan_rpm_under_tlr" | bc )

        fan_out_rpm_over=$(  echo "scale=3; $fan_out_rpm_std * $fan_rpm_over_tlr"  | bc )
        fan_out_rpm_under=$( echo "scale=3; $fan_out_rpm_std * $fan_rpm_under_tlr" | bc )
    else
        fan_rpm_over_tlr=$fan_lspd_rpm_tlr
        fan_rpm_under_tlr=$fan_lspd_rpm_tlr
        #fan_rpm_over_tlr=$(  echo "scale=3; (1 + $low_spd_rpm_tlr_range)" | bc )
        #fan_rpm_under_tlr=$( echo "scale=3; (1 - $low_spd_rpm_tlr_range)" | bc )

        fan_in_rpm_over=$(   echo "scale=3; ($fan_in_rpm_std + $fan_rpm_over_tlr)"  | bc )
        fan_in_rpm_under=$(  echo "scale=3; ($fan_in_rpm_std - $fan_rpm_under_tlr)" | bc )

        fan_out_rpm_over=$(  echo "scale=3; ($fan_out_rpm_std + $fan_rpm_over_tlr)"  | bc )
        fan_out_rpm_under=$( echo "scale=3; ($fan_out_rpm_std - $fan_rpm_under_tlr)" | bc )
    fi

    if (( $DBG_PRINT_FAN_RPM == 1 )); then
        curr_fan_pwm=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_PWM_REG; } 2>&1 )

        printf "Current Fan PWM              : %d (percent)\n" $curr_fan_pwm | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        #printf "Duty Cycle                  : %.2f\n" $duty_cycle

        printf "Fan PWM Breakpoint           : %d (percent)\n" $reg_fan_pwm_bkp      | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        printf "Fan Low Speed RPM Tolerance  : %d (rpm)\n" $fan_lspd_rpm_tlr | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        printf "Fan High Speed RPM Tolerance : %d (percent)\n" $reg_fan_hspd_rpm_tlr | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"

        printf "Fan Inner RPM Upper-Bound    : %.0f rpm\n" $fan_in_rpm_over  | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        printf "Fan Inner RPM Standard       : %.0f rpm\n" $fan_in_rpm_std   | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        printf "Fan Inner RPM Lower-Bound    : %.0f rpm\n" $fan_in_rpm_under | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"

        printf "Fan Outer RPM Upper-Bound    : %.0f rpm\n" $fan_out_rpm_over  | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        printf "Fan Outer RPM Standard       : %.0f rpm\n" $fan_out_rpm_std   | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        printf "Fan Outer RPM Lower-Bound    : %.0f rpm\n" $fan_out_rpm_under | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"

        printf "\n" | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        sync
    fi
}

function Read_Fan_Alert()
{
    for (( fan = 0; fan < $FAN_AMOUNT; fan += 1 ))
    do
        fan_alert_reg=$(( $MB_MCU_FAN_ALERT_REG + $fan ))
        fan_alert=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $fan_alert_reg; } 2>&1 )
        #printf "[Diag Debug] fan_alert : 0x%x\n" $fan_alert

        if [[ "$fan_alert" == "Error: Read failed" ]]; then
            printf "[Diag Err Msg] I2C Bus Read Fail\n"
            i2cdetect -y $I2C_BUS
            usleep $I2C_ACTION_DELAY
        else
            # ------------------------- Fan Present Alert ------------------------- #

            if (( ($fan_alert & $FB_MCU_PRESENT_ALERT_MASK) != $FALSE )); then
                fan_not_present_flag[$fan]=$TRUE
            fi

            # ------------------------- Fan Inner RPM Alert ------------------------- #

            if (( ($fan_alert & $FB_MCU_INNER_RPM_ZERO_MASK) != $FALSE )); then
                fan_in_rpm_zero_flag[$fan]=$TRUE
            fi

            if (( ($fan_alert & $FB_MCU_INNER_RPM_UNDER_MASK) != $FALSE )); then
                fan_in_rpm_under_flag[$fan]=$TRUE
            fi

            if (( ($fan_alert & $FB_MCU_INNER_RPM_OVER_MASK) != $FALSE )); then
                fan_in_rpm_over_flag[$fan]=$TRUE
            fi

            # ------------------------- Fan Outer RPM Alert ------------------------- #

            if (( ($fan_alert & $FB_MCU_OUTER_RPM_ZERO_MASK) != $FALSE )); then
                fan_out_rpm_zero_flag[$fan]=$TRUE
            fi

            if (( ($fan_alert & $FB_MCU_OUTER_RPM_UNDER_MASK) != $FALSE )); then
                fan_out_rpm_under_flag[$fan]=$TRUE
            fi

            if (( ($fan_alert & $FB_MCU_OUTER_RPM_OVER_MASK) != $FALSE )); then
                fan_out_rpm_over_flag[$fan]=$TRUE
            fi
        fi
    done

    ## Print Fan Present Alert
    for (( fan = 0; fan < $FAN_AMOUNT; fan += 1 ))
    do
        if (( ${fan_not_present_flag[$fan]} == $TRUE )); then
            fan_present_alert=$TRUE
            printf "[Fan %d] NOT Present.\n" $(( $fan + 1 )) | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        fi
    done
    printf "\n" | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
    sync

    ## Print Fan Zero / Inner / Outer RPM Alert
    for (( fan_in_out_sel = 1; fan_in_out_sel <= 2; fan_in_out_sel += 1 ))
    do
        for (( fan = 0; fan < $FAN_AMOUNT; fan += 1 ))
        do
            if (( $fan_in_out_sel == $INNER_FAN_SEL )); then
                if (( ${fan_in_rpm_zero_flag[$fan]} == $TRUE )); then
                    fan_rpm_alert=$TRUE
                    printf "[Fan %d] has Inner RPM Zero Alert.\n" $(( $fan + 1 )) | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                elif (( ${fan_in_rpm_under_flag[$fan]} == $TRUE )); then
                    fan_rpm_alert=$TRUE
                    printf "[Fan %d] has Inner RPM Under Alert.\n" $(( $fan + 1 )) | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                elif (( ${fan_in_rpm_over_flag[$fan]} == $TRUE )); then
                    fan_rpm_alert=$TRUE
                    printf "[Fan %d] has Inner RPM Over Alert.\n" $(( $fan + 1 )) | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                fi
            elif (( $fan_in_out_sel == $OUTER_FAN_SEL )); then
                if (( ${fan_out_rpm_zero_flag[$fan]} == $TRUE )); then
                    fan_rpm_alert=$TRUE
                    printf "[Fan %d] has Outer RPM Zero Alert.\n" $(( $fan + 1 )) | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                elif (( ${fan_out_rpm_under_flag[$fan]} == $TRUE )); then
                    fan_rpm_alert=$TRUE
                    printf "[Fan %d] has Outer RPM Under Alert.\n" $(( $fan + 1 )) | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                elif (( ${fan_out_rpm_over_flag[$fan]} == $TRUE )); then
                    fan_rpm_alert=$TRUE
                    printf "[Fan %d] has Outer RPM Over Alert.\n" $(( $fan + 1 )) | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                fi
            fi
        done

        if (( $fan_rpm_alert == $TRUE )); then
            printf "\n" | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        fi
    done
    sync
}

function Read_Fan_RPM()
{
    for (( fan_in_out_sel = 1; fan_in_out_sel <= 2; fan_in_out_sel += 1 ))  # choose fan inner/outer rpm
    do
        for (( fan = 0; fan < $FAN_AMOUNT; fan += 1 ))
        do
            if (( $fan_in_out_sel == $INNER_FAN_SEL )); then
                fan_rpm_reg=$(( $MB_MCU_FAN_INNER_RPM_BASE_REG | $fan ))
            elif (( $fan_in_out_sel == $OUTER_FAN_SEL )); then
                fan_rpm_reg=$(( $MB_MCU_FAN_OUTER_RPM_BASE_REG | $fan ))
            fi

            fan_rpm=$( { Read_I2C_Device_Node_Word $I2C_BUS $MB_MCU_ADDR $fan_rpm_reg ; } 2>&1 )

            if [[ "$fan_rpm" == "Error: Read failed" ]]; then
                printf "[Diag Err Msg] I2C Bus Read Fail\n"
                i2cdetect -y $I2C_BUS
                usleep $I2C_ACTION_DELAY
            else
                if (( $fan_in_out_sel == $INNER_FAN_SEL )); then
                    printf "[Fan %d] Inner R.P.M   :   %d rpm\n" $(( $fan + 1 )) $fan_rpm | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                elif (( $fan_in_out_sel == $OUTER_FAN_SEL )); then
                    printf "[Fan %d] Outer R.P.M   :   %d rpm\n" $(( $fan + 1 )) $fan_rpm | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                fi
            fi
        done
        printf "\n" | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
    done
    sync
}

function Run_Fan_Test()
{
    ## Variable Declaration
    ## fan_pwm_sel : A counter for setting low/midium/high fan PWM
    ## retry_cnt   : A counter for fan-test retry.
    ##               When fan RPM not falling in the tolerance range,
    ##               retry counter will count 1 and retry.
    fan_pwm_sel=1
    retry_cnt=0

    while (( $fan_pwm_sel <= 2 ))
    do
        if (( $retry_cnt == 0 )); then
            case $fan_pwm_sel in
                1)  fan_pwm=$FAN_TEST_LOW_SPEED       ;;
                2)  fan_pwm=$FAN_TEST_HIGH_SPEED      ;;
                *)  ;;
            esac

            printf "\n========================= Fan PWM Set To %d =========================\n\n" $fan_pwm | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"

            # i2cset -y 1 0x70 0x10 $fan_pwm
            Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_PWM_REG $fan_pwm

            sleep 10

            Get_Fan_RPM_Tolerance_Range $fan_pwm
        else
            printf "\n==================== Fan PWM Set To %d --- Retry Round %d/%d ====================\n\n" $fan_pwm $retry_cnt $FAN_TEST_RETRY_TIMES | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
        fi

        ## Initialize
        for (( fan = 0; fan < $FAN_AMOUNT; fan += 1 ))
        do
            fan_not_present_flag[$fan]=$FALSE

            fan_in_rpm_zero_flag[$fan]=$FALSE
            fan_in_rpm_under_flag[$fan]=$FALSE
            fan_in_rpm_over_flag[$fan]=$FALSE

            fan_out_rpm_zero_flag[$fan]=$FALSE
            fan_out_rpm_under_flag[$fan]=$FALSE
            fan_out_rpm_over_flag[$fan]=$FALSE
        done

        fan_present_alert=$FALSE
        fan_rpm_alert=$FALSE

        Read_Fan_Alert
        usleep $I2C_ACTION_DELAY

        Read_Fan_RPM
        usleep $I2C_ACTION_DELAY

        # --------------------------------------------------------------------------------------------------------- #

        if (( $fan_present_alert == $TRUE )) || (( $fan_rpm_alert == $TRUE )); then
            retry_cnt=$(( $retry_cnt + 1 ))

            if (( $retry_cnt > $FAN_TEST_RETRY_TIMES )); then
                printf "[Diag Error Msg] Fan Test Under Fan PWM %d ---> Retry %d Round FAIL\n" $fan_pwm $(( $retry_cnt - 1 )) | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                DIAG_LOCAL_FAN_TEST_RESULT=$FAIL
                break
            fi

            sleep $FAN_TEST_RETRY_DELAY_TIME
        else
            if (( $DBG_PRINT_FAN_TEST_RESULT == 1 )); then
                if (( $retry_cnt == 0 )); then
                    printf "[Diag Msg] Fan Test Under Fan PWM %d ---> No Retry PASS\n" $fan_pwm | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                else
                    printf "[Diag Msg] Fan Test Under Fan PWM %d ---> Retry %d Times PASS\n" $fan_pwm $retry_cnt | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
                    retry_cnt=0
                fi
            fi

            fan_pwm_sel=$(( $fan_pwm_sel + 1 ))
        fi

        ## Clear fan alert register by read it out.
        for (( fan = 0; fan < $FAN_AMOUNT; fan += 1 ))
        do
            fan_alert_reg=$(( $MB_MCU_FAN_ALERT_REG + $fan ))
            fan_alert=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $fan_alert_reg; } 2>&1 )
        done
        sleep 3

        printf "\n============================================================\n" | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"
    done
    sync

    ## Set MainBoard MCU alert register to "auto clear" mode
    # i2cset -y 0 0x70 0x59 0x1
    Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_FAN_ALERT_MODE_REG $MB_MCU_FAN_ALERT_MODE_AUTO

    ## Set SmartFan "enable"(auto mode)
    # i2cset -y 0 0x70 0x11 0x1
    if (( $DBG_FAN_TEST == $FALSE )); then
        Write_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_SMARTFAN_ENABLE_BASE_REG $MB_MCU_SMARTFAN_ENABLE
    fi
}

function Fan_Test_Result_Dump()
{
    #echo "[Diag] Fan Test Result"

    if (( $DIAG_LOCAL_FAN_TEST_RESULT == $PASS )); then
        #echo "Fan Test Result : PASS" | tee "$DIAG_FAN_TEST_RESULT_LOG_FILE_NAME"
        echo "Fan Test Result : PASS" > "$DIAG_FAN_TEST_RESULT_LOG_FILE_NAME"
    elif (( $DIAG_LOCAL_FAN_TEST_RESULT == $FAIL )); then
        #echo "Fan Test Result : FAIL" | tee "$DIAG_FAN_TEST_RESULT_LOG_FILE_NAME"
        echo "Fan Test Result : FAIL" > "$DIAG_FAN_TEST_RESULT_LOG_FILE_NAME"
    fi
    sync
}

function Mutex_Check_And_Create()
{
    ## check whether mutex key create by others process, if exist, wait until this procedure can create then keep go test.
    while [ -f $I2C_MUTEX_NODE ]
    do
        #echo " !!! Wait for I2C bus free !!!"
        sleep 1
        if [ ! -f $I2C_MUTEX_NODE ]; then
            break
        fi
    done
    ## create mutex key
    touch $I2C_MUTEX_NODE
    sync
    usleep 100000
}

function Mutex_Clean()
{
    rm $I2C_MUTEX_NODE
    sync
    usleep 100000
}

# ======================================================================================================================================= #

### Main Function ###

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

echo "[Diag] Power Cycle Round $curr_pwr_cyc_round" >> "$DIAG_FAN_TEST_LOG_FILE_NAME"
echo "           This is Fan Test Log" >> "$DIAG_FAN_TEST_LOG_FILE_NAME"
echo "" >> "$DIAG_FAN_TEST_LOG_FILE_NAME"
sync

date | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"

## Switch I2C MUX to MainBoard MCU
# i2cset -y 0 0x72 0x0 0x7
Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU

## Add FanBoard I2C bus alert check before do fan test.
# i2cget -y 0 0x70 0x58
i2c_bus_alert=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $MB_MCU_I2C_BUS_ALERT_REG; } 2>&1 )

if (( ($i2c_bus_alert & $FB_MCU_I2C_BUS_ALERT_MASK) != $FALSE )); then
    # Cannot detect FanBoard via I2C bus.
    printf "[Diag Error Msg] Cannot detect fan board via I2C bus.\n\n" | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"

    DIAG_LOCAL_FAN_TEST_RESULT=$FAIL
    Fan_Test_Result_Dump
else
    Write_Fan_Test_Setting

    Read_Fan_Test_Setting

    Run_Fan_Test

    Fan_Test_Result_Dump
fi

date | tee -a "$DIAG_FAN_TEST_LOG_FILE_NAME"

usleep $I2C_ACTION_DELAY
sync

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
