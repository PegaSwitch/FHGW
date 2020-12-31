#!/bin/bash
## create by Jenny, for Gemini (Marvell)

OUTPUT_FILE="/home/root/mfg/burnin_configuration"
SDK_INIT_LOG="/home/root/testLog/MAC/sdk_init.log"

#config_qsfp_speed=5    # 100G
#config_sfp_speed=2     # 25G
config_interface=4      # lbm
#config_vlan=4          # one vlan per 2-ports
config_traffic_seconds=60
config_mode=3           # Burn-In = 3 ; PT_4C = 6   // define same as in SDK.
config_tfc_cycle=1
config_tfc_round=1

function Help_Input ()
{
    echo "Please enter at least 1 parameters !"
    echo "    # Packet traffic time (second) [1 ~ ]"
    echo "    # Module Interface        [fiber/lbm/DAC]  (optional)"
    echo ""
    echo "    Ex: ./mfg_sources/gemini_burnin.sh seconds=1000"
}

function Input_Get ()
{
    input_string=$1
    IFS='=' read -ra input_parts <<< "$input_string"
    input_item=${input_parts[0]}
    input_value=${input_parts[1]}

    if [[ $input_item == "seconds" ]] || [[ $input_item == "sec" ]] || [[ $input_item == "time" ]] || [[ $input_item == "packet_time" ]]; then
        if (( $input_value > 0 )); then
            config_traffic_seconds=$input_value
            echo " # packet transmit seconds : $input_value"    ## for show/debug
        else
            echo "  Invalid packet number setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "if" ]] || [[ $input_item == "interface" ]] || [[ $input_item == "Interface" ]]; then
        if [[ $input_value == "DAC" ]] || [[ $input_value == "fiber" ]] || [[ $input_value == "lbm" ]] ; then
            if [[ $input_value == "DAC" ]]; then
                sdk_if=1
            elif [[ $input_value == "fiber" ]]; then
                sdk_if=2
            elif [[ $input_value == "lbm" ]]; then
                sdk_if=3
            fi
            config_interface=$sdk_if
            echo " # Interface : $input_value"    ## for show/debug
        else
            echo "  Invalid interface setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "mode" ]] || [[ $input_item == "tfc-mode" ]]; then
        if (( $input_value > 0 )); then
            config_mode=$input_value
            echo " # traffic mode : $input_value"    ## for show/debug
        else
            echo "  Invalid traffic mode setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "cycle" ]] || [[ $input_item == "tfc-cycle" ]]; then
        if (( $input_value > 0 )); then
            config_tfc_cycle=$input_value
            echo " # traffic cycle : $input_value"    ## for show/debug
        else
            echo "  Invalid traffic cycle setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "round" ]] || [[ $input_item == "tfc-round" ]]; then
        if (( $input_value > 0 )); then
            config_tfc_round=$input_value
            echo " # traffic round : $input_value"    ## for show/debug
        else
            echo "  Invalid traffic round setting!"
            Help_Input
            exit 1
        fi
    fi

    ## Output to configure file.
    echo "TIME=$config_traffic_seconds" > $OUTPUT_FILE
    echo "INTERFACE=$config_interface" >> $OUTPUT_FILE
    echo "TRAFFIC_MODE=$config_mode" >> $OUTPUT_FILE
    echo "TRAFFIC_CYCLE=$config_tfc_cycle" >> $OUTPUT_FILE
    echo "TRAFFIC_ROUND=$config_tfc_round" >> $OUTPUT_FILE
}

function Input_Help ()
{
    input_string=$1

    if [[ $input_string == "-h" ]] || [[ $input_string == "-help" ]] || [[ $input_string == "--h" ]] || [[ $input_string == "--help" ]] || [[ $input_string == "?" ]]; then
        Help_Input
        exit 1
    fi
}

Input_Help $1

Input_Get $1
if [ ! -z "$2" ]; then
    Input_Get $2
fi
if [ ! -z "$3" ]; then
    Input_Get $3
fi
if [ ! -z "$4" ]; then
    Input_Get $4
fi
if [ ! -z "$5" ]; then
    Input_Get $5
fi

#cat $OUTPUT_FILE    ## for debug

## Execute SDK
/home/root/mfg/appDemo -redir_stdout $SDK_INIT_LOG

