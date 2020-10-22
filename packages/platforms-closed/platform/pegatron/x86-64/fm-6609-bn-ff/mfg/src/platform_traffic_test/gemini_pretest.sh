#!/bin/bash
## create by Jenny, for Gemini (Marvell)

OUTPUT_FILE="/home/root/mfg/pretest_configuration"

config_qsfp_speed=5    # 100G
config_sfp_speed=2     # 25G
config_interface=4     # lbm
config_vlan=3          # single vlan per port
config_packet_number=1000

function Help_Input ()
{
    echo "Please enter at least 2 parameters (QSFP & SFP speed)!!!"
    echo "    # QSFP          [*100/50/40/25/10]"
    echo "    # SFP           [*25/10]"
    echo "    # Packet Number [1 ~ 10000]"
    echo ""
    echo "    Ex: ./mfg_sources/gemini_pretest.sh qsfp=100 sfp=25 packet=1000"
}

function Input_Get ()
{
    input_string=$1
    IFS='=' read -ra input_parts <<< "$input_string"
    input_item=${input_parts[0]}
    input_value=${input_parts[1]}

    if [[ $input_item == "qsfp" ]] || [[ $input_item == "QSFP" ]]; then
        if [[ $input_value == "100" ]] || [[ $input_value == "50" ]] || [[ $input_value == "40" ]] || [[ $input_value == "25" ]] || [[ $input_value == "10" ]]; then
            if [[ $input_value == "100" ]]; then
                sdk_qsfp=5
            elif [[ $input_value == "50" ]]; then
                sdk_qsfp=4
            elif [[ $input_value == "40" ]]; then
                sdk_qsfp=3
            elif [[ $input_value == "25" ]]; then
                sdk_qsfp=2
            elif [[ $input_value == "10" ]]; then
                sdk_qsfp=1
            fi
            config_qsfp_speed=$sdk_qsfp
            echo " # QSFP : $input_value G"    ## for show/debug
        else
            echo "  Invalid QSFP speed setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "sfp" ]] || [[ $input_item == "SFP" ]]; then
        if [[ $input_value == "25" ]] || [[ $input_value == "10" ]]; then
            if [[ $input_value == "25" ]]; then
                sdk_sfp=2
            elif [[ $input_value == "10" ]]; then
                sdk_sfp=1
            fi
            config_sfp_speed=$sdk_sfp
            echo " # SFP : $input_value G"    ## for show/debug
        else
            echo "  Invalid SFP speed setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "packet" ]] || [[ $input_item == "pkt" ]] || [[ $input_item == "number" ]] || [[ $input_item == "packet_number" ]]; then
        if (( $input_value <= 10000 )); then
            config_packet_number=$input_value
            echo " # packet number : $input_value"    ## for show/debug
        else
            echo "  Invalid packet number setting!"
            Help_Input
            exit 1
        fi
    fi

    ## Output to configure file.
    echo "QSFP=$config_qsfp_speed" > $OUTPUT_FILE
    echo "SFP=$config_sfp_speed" >> $OUTPUT_FILE
    echo "INTERFACE=$config_interface" >> $OUTPUT_FILE
    echo "VLAN=$config_vlan" >> $OUTPUT_FILE
    echo "PKTCOUNT=$config_packet_number" >> $OUTPUT_FILE
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
Input_Get $2
Input_Get $3
Input_Get $4

#cat $OUTPUT_FILE    ## for debug

## Execute SDK
/home/root/mfg/appDemo

