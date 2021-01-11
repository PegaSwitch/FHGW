#!/bin/bash
# Purpose: This script is to monitor multiphase controllers' detail information.

## variables defined ::
source ${HOME}/mfg/mfg_sources/platform_detect.sh

debug_flag=0

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
    sleep $I2C_ACTION_DELAY
}

function Read_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register
        sleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE ; } 2>&1 )
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
        sleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_TWO ; } 2>&1 )
        #echo $value_get_through_ipmi    # for debug, value format is " XX XX"
        sleep $I2C_ACTION_DELAY
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

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# |7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# <----N----><---------Y---------->
# <-b[7:3]--><---b[2:0],b[7:0]---->
# X=Y*2^N
# X is the real world value
# Y is an 11-bit, two's complement integer
# N is an 5-bit, two's complement integer

# 15=01111'b ; 32=10000'b*2
function Linear_2sComplement_Format_Exponent()
{
    x=$((10#$1)); [ "$x" -gt 15 ] && ((x=x-32)); exponVal=$x;
}

# 1023=011_1111_1111'b ; 2048=100_0000_0000'b*2
function Linear_2sComplement_Format_Mantissa()
{
    x=$((10#$1)); [ "$x" -gt 1023 ] && ((x=x-2048)); mantissaVal=$x;
}

function Twos_Complement_Calculator()
{
    expon=$( { echo $(( ( $1 & 0xf800 ) >> 11 )) ; } 2>&1 )
    Linear_2sComplement_Format_Exponent $expon
    #printf "[Debug] exponVal -> %f\n" $exponVal

    mantissa=$( { echo $(( $1 & 0x07ff )) ; } 2>&1 )
    Linear_2sComplement_Format_Mantissa $mantissa
    #printf "[Debug] mantissaVal -> %f\n" $mantissaVal

    if (( $exponVal < 0 )); then
        exponVal=$(( $exponVal * -1 ))
        real_world_val=$( echo "scale=3; $mantissaVal / $(( 2 ** $exponVal ))" | bc )
    else
        real_world_val=$( echo "scale=3; $mantissaVal * $(( 2 ** $exponVal ))" | bc )
    fi

    #printf "[Debug] real_world_val -> %f\n" $real_world_val
}

function MPC_TPS53679_VOUT_To_VID_Format()
{
    dac_step="$1"
    vid_hex_val=$2

    #echo "[Debug] dac_step    ---> $dac_step"
    #echo "[Debug] vid_hex_val ---> $vid_hex_val"

    if [[ "$dac_step" == "5mV" ]]; then
        if (( $vid_hex_val > 0 )); then
            vid_dec_val=$( echo "scale=3; 0.25 + 0.005 * $(($vid_hex_val - 1))" | bc )
        else
            vid_dec_val=0
        fi
    elif [[ "$dac_step" == "10mV" ]]; then
        if (( $vid_hex_val > 0 )); then
            vid_dec_val=$( echo "scale=3; 0.50 + 0.01 * $(($vid_hex_val - 1))"  | bc )
        else
            vid_dec_val=0
        fi
    else
        echo "[MFG Error Msg] MPC TPS53679 DAC Step Setting Error !!!"
    fi

    #printf "[Debug] vid_dec_val : %.3f\n" $vid_dec_val

    real_world_val=$vid_dec_val
}

function MultiPhase_Controller_TPS536XX_Monitor()
{
    model_name="$1"
    board_type="$2"
    dev_addr=$3
    channel="$4"

    if [[ "$board_type" == "mb" ]]; then
        i2c_bus=$I2C_BUS_PMBUS
    elif [[ "$board_type" == "npu" ]]; then
        i2c_bus=$I2C_BUS_ARBITER_AND_AFTER
    fi

    if [[ "$channel" == "shared" ]]; then
        # Shared between channel A and B. (read the same value from page A and B)
        Write_I2C_Device_Node $i2c_bus $dev_addr $MPC_TPS536XX_PAGE_REG 0x0
    elif [[ "$channel" == "ch_a" ]]; then
        # Switch to channel A page.
        str_ch="Ch-A"
        Write_I2C_Device_Node $i2c_bus $dev_addr $MPC_TPS536XX_PAGE_REG 0x0
    elif [[ "$channel" == "ch_b" ]]; then
        # Switch to channel B page.
        str_ch="Ch-B"
        Write_I2C_Device_Node $i2c_bus $dev_addr $MPC_TPS536XX_PAGE_REG 0x1
    elif [[ "$channel" == "simul" ]]; then
        # Simultaneous access channels A and B.
        Write_I2C_Device_Node $i2c_bus $dev_addr $MPC_TPS536XX_PAGE_REG 0xff
    fi

    if [[ "$channel" == "shared" ]]; then
        # Read V_IN (Shared Channel)
        # The two data bytes(read word transactions) are formatted in the Linear Data format.
        vin_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $MPC_TPS536XX_READ_VIN_REG ; } 2>&1 )

        Twos_Complement_Calculator $vin_val

        if (( $debug_flag == $TRUE )); then
            echo "[MFG Debug] Input Voltage (Shared Channel) [Register: $MPC_TPS536XX_READ_VIN_REG]"
            echo "[MFG Debug] register value: $vin_val ; real world value: $real_world_val"
            echo ""
        else
            printf "\tInput Voltage  (Shared Channel) : %.3f (V)\n" $real_world_val
        fi

        # ------------------------------------------------------------------------------------------------------------------------ #

        # Read I_IN (Shared Channel)
        iin_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $MPC_TPS536XX_READ_I_IN_REG ; } 2>&1 )

        Twos_Complement_Calculator $iin_val

        if (( $debug_flag == $TRUE )); then
            echo "[MFG Debug] Input Current (Shared Channel) [Register: $MPC_TPS536XX_READ_I_IN_REG]"
            echo "[MFG Debug] register value: $iin_val ; real world value: $real_world_val"
            echo ""
        else
            printf "\tInput Current  (Shared Channel) : %.3f (A)\n" $real_world_val
        fi
    elif [[ "$channel" == "simul" ]]; then
        if [[ "$model_name" == "tps53679" ]]; then
            str_temp="Temperature-1"
            mpc_read_temp_reg=$MPC_TPS536XX_READ_TEMPERATURE_1_REG
        elif [[ "$model_name" == "tps536c7" ]]; then
            str_temp="Temperature-2"
            mpc_read_temp_reg=$MPC_TPS536XX_READ_TEMPERATURE_2_REG
        fi

        # Read Temperature (Simultaneous Channel A and B)
        temp_sim_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $mpc_read_temp_reg ; } 2>&1 )

        Twos_Complement_Calculator $temp_sim_val

        if (( $debug_flag == $TRUE )); then
            echo "[MFG Debug] $str_temp (Simul Ch-A & Ch-B) [Register: $mpc_read_temp_reg]"
            echo "[MFG Debug] register value: $temp_sim_val ; real world value: $real_world_val"
            echo ""
        else
            printf "\t%s  (Simul Ch-A & Ch-B) : %.2f (Celsius degree)\n" "$str_temp" $real_world_val
        fi

        # ------------------------------------------------------------------------------------------------------------------------ #

        # Read P_OUT (Simultaneous Channel A and B)
        pout_sim_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $MPC_TPS536XX_READ_P_OUT_REG ; } 2>&1 )

        Twos_Complement_Calculator $pout_sim_val

        if (( $debug_flag == $TRUE )); then
            echo "[MFG Debug] Output Power (Simul Ch-A & Ch-B) [Register: $MPC_TPS536XX_READ_P_OUT_REG]"
            echo "[MFG Debug] register value: $pout_sim_val ; real world value: $real_world_val"
            echo ""
        else
            printf "\tOutput Power   (Simul Ch-A & Ch-B) : %.3f (W)\n" $real_world_val
        fi

        # ------------------------------------------------------------------------------------------------------------------------ #

        # Read P_IN (Simultaneous Channel A and B)
        pin_sim_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $MPC_TPS536XX_READ_P_IN_REG ; } 2>&1 )

        Twos_Complement_Calculator $pin_sim_val

        if (( $debug_flag == $TRUE )); then
            echo "[MFG Debug] Input Power (Simul Ch-A & Ch-B) [Register: $MPC_TPS536XX_READ_P_IN_REG]"
            echo "[MFG Debug] register value: $pin_sim_val ; real world value: $real_world_val"
        else
            printf "\tInput Power    (Simul Ch-A & Ch-B) : %.3f (W)\n" $real_world_val
        fi
    else
        # Read V_OUT (Channel A and B)
        vout_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $MPC_TPS536XX_READ_V_OUT_REG ; } 2>&1 )

        # Power Team provide VID_DAC_STEP setting.
        if [[ "$board_type" == "mb" ]]; then
            if [[ "$model_name" == "tps53679" ]]; then
                vout_dac_step="10mV"
            elif [[ "$model_name" == "tps536c7" ]]; then
                vout_dac_step="not-used"
            fi
        elif [[ "$board_type" == "npu" ]]; then
            if [[ "$model_name" == "tps53679" ]]; then
                if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
                    vout_dac_step="10mV"
                elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
                    vout_dac_step="5mV"
                else
                    echo "[MFG Error Msg] CPU model NOT support yet !!!\n"
                fi
            fi
        fi

        if [[ "$model_name" == "tps53679" ]]; then
            MPC_TPS53679_VOUT_To_VID_Format $vout_dac_step $vout_val
        elif [[ "$model_name" == "tps536c7" ]]; then
            real_world_val=$( echo "scale=3; $((vout_val)) / 1000" | bc )
        fi

        if (( $debug_flag == $TRUE )); then
            echo "[MFG Debug] Output Voltage (${str_ch}) [Register: $MPC_TPS536XX_READ_V_OUT_REG]"
            echo "[MFG Debug] register value: $vout_val ; real world value: $real_world_val"
            echo ""
        else
            if [[ "$SUPPORT_CPU" == "BDXDE" && "$dev_addr" == "0x64" ]] && [[ "$channel" == "ch_a" ]]; then
                printf "\t%s not used in BDX-DE\n" "$str_ch" #> /dev/zero
            else
                printf "\tOutput Voltage (%s) : %.3f (V)\n" "$str_ch" $real_world_val
            fi
        fi

        # ------------------------------------------------------------------------------------------------------------------------ #

        if (( $debug_flag == $TRUE )); then   # Read each phase I_OUT value. (for debug)
            if [[ "$PROJECT_NAME" == "ASTON" ]] && [[ "$board_type" == "mb" ]]; then
                # phase number need check by TI GUI tool
                if [[ $mpc_mb_addr == $PMBUS_MB_A_ADDR ]]; then
                    if [[ "$channel" == "ch_a" ]]; then
                        phase_num=10
                    elif [[ "$channel" == "ch_b" ]]; then
                        phase_num=2
                    fi
                elif [[ $mpc_mb_addr == $PMBUS_MB_B_ADDR ]]; then
                    if [[ "$channel" == "ch_a" ]]; then
                        phase_num=6
                    elif [[ "$channel" == "ch_b" ]]; then
                        phase_num=0 # unused
                    fi
                fi
            else
                phase_num=6
            fi

            # Select Phase 1~N
            for (( phase = 0; phase < $phase_num; phase += 1 ))
            do
                Write_I2C_Device_Node $i2c_bus $dev_addr $MPC_TPS536XX_PHASE_REG $phase

                iout_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $MPC_TPS536XX_READ_I_OUT_REG ; } 2>&1 )

                Twos_Complement_Calculator $iout_val

                #printf "\tOutput Current (%s, Phase-%d) : %.3f (A)\n" "$str_ch" $(( $phase + 1 )) $real_world_val
                echo "[MFG Debug] Output Current (${str_ch}, Phase-$(( $phase + 1 )))"
                echo "[MFG Debug] register value: $iout_val ; real world value: $real_world_val"
            done
            echo ""
        fi

        # Read I_OUT (Channel A and B)
        if [[ "$model_name" == "tps53679" ]]; then
            MPC_TPS536XX_READ_PHASE_SIMUL_VAL=0xFF  # TPS53679: Simultaneous Phase 1~6
            MPC_TPS536XX_READ_PHASE_ALL_VAL=0x80    # TPS53679: Total Phase 1~6
        elif [[ "$model_name" == "tps536c7" ]]; then
            MPC_TPS536XX_READ_PHASE_ALL_VAL=0xFF    # TPS536C7: All phases in the "PAGE" as a single entity.
        fi

        if [[ "$model_name" == "tps53679" ]]; then
            Write_I2C_Device_Node $i2c_bus $dev_addr $MPC_TPS536XX_PHASE_REG $MPC_TPS536XX_READ_PHASE_SIMUL_VAL

            iout_sim_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $MPC_TPS536XX_READ_I_OUT_REG ; } 2>&1 )

            Twos_Complement_Calculator $iout_sim_val

            if (( $debug_flag == $TRUE )); then
                echo "[MFG Debug] Output Current ($str_ch Simul Phase) [Register: $MPC_TPS536XX_READ_I_OUT_REG]"
                echo "[MFG Debug] register value: $iout_sim_val ; real world value: $real_world_val"
                echo ""
            else
                if [[ "$SUPPORT_CPU" == "BDXDE" && "$dev_addr" == "0x64" ]] && [[ "$channel" == "ch_a" ]]; then
                    printf "\t%s not used in BDX-DE\n" "$str_ch" #> /dev/zero
                else
                    printf "\tOutput Current (%s, Simul Phase) : %.3f (A)\n" "$str_ch" $real_world_val
                fi
            fi
        fi

        # ------------------------------------------------------------------------------------------------------------------------ #

        Write_I2C_Device_Node $i2c_bus $dev_addr $MPC_TPS536XX_PHASE_REG $MPC_TPS536XX_READ_PHASE_ALL_VAL

        iout_total_val=$( { Read_I2C_Device_Node_Word $i2c_bus $dev_addr $MPC_TPS536XX_READ_I_OUT_REG ; } 2>&1 )

        Twos_Complement_Calculator $iout_total_val

        if (( $debug_flag == $TRUE )); then
            echo "[MFG Debug] Output Current ($str_ch Total Phase) [Register: $MPC_TPS536XX_READ_I_OUT_REG]"
            echo "[MFG Debug] register value: $iout_total_val ; real world value: $real_world_val"
            echo ""
        else
            if [[ "$SUPPORT_CPU" == "BDXDE" && "$dev_addr" == "0x64" ]] && [[ "$channel" == "ch_a" ]]; then
                printf "\t%s not used in BDX-DE\n" "$str_ch" #> /dev/zero
            else
                printf "\tOutput Current (%s, Total Phase) : %.3f (A)\n" "$str_ch" $real_world_val
            fi
        fi
    fi
}

function MultiPhase_Controller_TPS40428_Monitor()
{
    dev_addr=$1

    # Switch to Channel-A Page
    Write_I2C_Device_Node $I2C_BUS_PMBUS $dev_addr 0x0 0x0

    # Read V_OUT (Channel A)
    vout_a_mantissa=$( { Read_I2C_Device_Node_Word $I2C_BUS_PMBUS $dev_addr 0x8B ; } 2>&1 )
    real_world_val=$( echo "scale=3; $((vout_a_mantissa)) / 512" | bc )
    printf "\tOutput Voltage (Ch-A) : %.3f (V)\n" $real_world_val

    # ------------------------------------------------------------ #

    # Read I_OUT (Channel A)
    iout_a=$( { Read_I2C_Device_Node_Word $I2C_BUS_PMBUS $dev_addr 0x8C ; } 2>&1 )
    Twos_Complement_Calculator $iout_a
    printf "\tOutput Current (Ch-A) : %.3f (A)\n" $real_world_val

    # ============================================================ #

    if (( 0 )); then    # Bugatti2/Porsche2/Mercedes3 didn't use channel-B
        # Switch to Channel-B Page
        Write_I2C_Device_Node $I2C_BUS_PMBUS $dev_addr 0x0 0x1

        # Read V_OUT (Channel B)
        vout_b_mantissa=$( { Read_I2C_Device_Node_Word $I2C_BUS_PMBUS $dev_addr 0x8B ; } 2>&1 )
        real_world_val=$( echo "scale=3; $((vout_b_mantissa)) / 512" | bc )
        printf "\tOutput Voltage (Ch-B) : %.3f (V)\n" $real_world_val

        # ------------------------------------------------------------ #

        # Read I_OUT (Channel B)
        iout_b=$( { Read_I2C_Device_Node_Word $I2C_BUS_PMBUS $dev_addr 0x8C ; } 2>&1 )
        Twos_Complement_Calculator $iout_b
        printf "\tOutput Current (Ch-B) : %.3f (A)\n" $real_world_val
    fi

    # ============================================================ #

    # Switch to Simultaneous Page
    Write_I2C_Device_Node $I2C_BUS_PMBUS $dev_addr 0x0 0x81

    # Read Temperature_2 (Simultaneous Channel A and B)
    temp_2=$( { Read_I2C_Device_Node_Word $I2C_BUS_PMBUS $dev_addr 0x8E ; } 2>&1 )
    Twos_Complement_Calculator $temp_2
    printf "\tTemperature-2  (Simul Ch-A & Ch-B) : %.2f (Celsius degree)\n" $real_world_val

    printf "\n"
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
    sleep $I2C_ACTION_DELAY
}

function Mutex_Clean()
{
    rm $I2C_MUTEX_NODE
    sync
    sleep $I2C_ACTION_DELAY
}

function I2C_Arbiter_Request()
{
    request=$1

    if (( $request == 1 )); then
        # i2cset -y 0 0x71 0x1 0x1
        i2cset -y $I2C_BUS_ARBITER_AND_AFTER $I2C_ARBITER_ADDR $I2C_ARBITER_CTRL_REG 0x1
        sleep $I2C_ACTION_DELAY

        # i2cset -y 0 0x71 0x1 0x7
        i2cset -y $I2C_BUS_ARBITER_AND_AFTER $I2C_ARBITER_ADDR $I2C_ARBITER_CTRL_REG 0x7
        sleep $I2C_ACTION_DELAY
    elif (( $request == 0 )); then
        # i2cset -y 0 0x71 0x1 0x0
        i2cset -y $I2C_BUS_ARBITER_AND_AFTER $I2C_ARBITER_ADDR $I2C_ARBITER_CTRL_REG 0x0
        sleep $I2C_ACTION_DELAY
    fi
}

### Main ###

## Send I2C arbiter request. (LOCK for CPU use.)
#I2C_Arbiter_Request $I2C_ARBITER_LOCK

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

printf "\t{ Multiphase Controller Information }\n"
printf "\n"

if [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
    # Set PWM SCL Mux Control Register(PSMCR), select to CPU
    Write_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_1 $CPLD_B_ADDR 0x14 0x1
elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
    # Set PWM SCL Mux Control Register(VRMCR), select to CPU
    Write_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_0 $CPLD_A_ADDR 0x0F 0x1
fi

if [[ "$PROJECT_NAME" == "ASTON" ]]; then
    # Main Board Multiphase Controller A
    printf "\tTPS536C7 (MB  0x66) Info :\n"
    MultiPhase_Controller_TPS536XX_Monitor "tps536c7" "mb" $PMBUS_MB_A_ADDR "shared"
    MultiPhase_Controller_TPS536XX_Monitor "tps536c7" "mb" $PMBUS_MB_A_ADDR "simul"
    MultiPhase_Controller_TPS536XX_Monitor "tps536c7" "mb" $PMBUS_MB_A_ADDR "ch_a"
    MultiPhase_Controller_TPS536XX_Monitor "tps536c7" "mb" $PMBUS_MB_A_ADDR "ch_b"
    printf "\n"

    # Main Board Multiphase Controller B
    printf "\tTPS536C7 (MB  0x6A) Info :\n"
    MultiPhase_Controller_TPS536XX_Monitor "tps536c7" "mb" $PMBUS_MB_B_ADDR "shared"
    MultiPhase_Controller_TPS536XX_Monitor "tps536c7" "mb" $PMBUS_MB_B_ADDR "simul"
    MultiPhase_Controller_TPS536XX_Monitor "tps536c7" "mb" $PMBUS_MB_B_ADDR "ch_a"
    printf "\n"
elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    for (( mpc_index = 1; mpc_index <= 3; mpc_index += 1 ))
    do
        if (( $mpc_index == 1 )); then
            # Main Board Multiphase Controller A
            printf "\tTPS53679 (MB  0x60) Info :\n"
            mpc_mb_addr=$PMBUS_MB_A_ADDR
        elif (( $mpc_index == 2 )); then
            # Main Board Multiphase Controller B
            printf "\tTPS40428 (MB  0x09) Info :\n"
            MultiPhase_Controller_TPS40428_Monitor $PMBUS_MB_B_ADDR
            continue
        else
            # Main Board Multiphase Controller C
            printf "\tTPS53679 (MB  0x5F) Info :\n"
            mpc_mb_addr=$PMBUS_MB_C_ADDR
        fi

        MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $mpc_mb_addr "shared"
        MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $mpc_mb_addr "simul"
        MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $mpc_mb_addr "ch_a"
        MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $mpc_mb_addr "ch_b"
        printf "\n"
    done
elif [[ "$PROJECT_NAME" == "FHGW" ]]; then
    printf "\tTPS53679 (MB  0x60) Info :\n"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $PMBUS_MB_A_ADDR "shared"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $PMBUS_MB_A_ADDR "simul"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $PMBUS_MB_A_ADDR "ch_a"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $PMBUS_MB_A_ADDR "ch_b"
else
    printf "\tTPS53679 (MB  0x60) Info :\n"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $PMBUS_MB_A_ADDR "shared"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $PMBUS_MB_A_ADDR "simul"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $PMBUS_MB_A_ADDR "ch_a"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "mb" $PMBUS_MB_A_ADDR "ch_b"

    # Main Board Multiphase Controller B
    printf "\tTPS40428 (MB  0x09) Info :\n"
    MultiPhase_Controller_TPS40428_Monitor $PMBUS_MB_B_ADDR
fi

# CPLD's MCR register reset to default
if [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
    Write_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_1 $CPLD_B_ADDR 0x14 0x0
elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
    Write_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_0 $CPLD_A_ADDR 0x0F 0x0
fi

for (( mpc_index = 1; mpc_index <= 2; mpc_index += 1 ))
do
    if (( $mpc_index == 1 )); then
        # NPU Board Multiphase Controller D
        printf "\tTPS53679 (NPU 0x63) Info :\n"
        mpc_npu_addr=$PMBUS_NPU_63_ADDR
    else
        # NPU Board Multiphase Controller E
        printf "\tTPS53679 (NPU 0x64) Info :\n"
        mpc_npu_addr=$PMBUS_NPU_64_ADDR
    fi

    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "npu" $mpc_npu_addr "shared"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "npu" $mpc_npu_addr "simul"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "npu" $mpc_npu_addr "ch_a"
    MultiPhase_Controller_TPS536XX_Monitor "tps53679" "npu" $mpc_npu_addr "ch_b"

    printf "\n"
done

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi

## Cancel I2C arbiter request. (RELEASE for others use.)
# I2C_Arbiter_Request $I2C_ARBITER_RELEASE
