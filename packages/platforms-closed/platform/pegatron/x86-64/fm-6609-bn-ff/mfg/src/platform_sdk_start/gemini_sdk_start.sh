#!/bin/bash
## create by Jenny, for Gemini (Marvell)

OUTPUT_FILE="/home/root/mfg/sdk_configuration"

config_qsfp_speed=5    # 100G
config_sfp_speed=2     # 25G
config_interface=2     # fiber (CAUI-4)
config_vlan=0          # off (no vlan)
config_fec=0           # disable
config_flooding=-1     # no need flooding (sec)
#config_an="off"

function Help_Input ()
{
    echo "Please enter at least 2 parameters (QSFP & SFP speed)!!!"
    echo "    # QSFP          [*100/50/40/25/10]"
    echo "    # SFP           [*25/10]"
    echo "    # Interface     [*fiber/DAC/lbm]"
    echo "    # VLAN          [*off/on/single]"
    echo "    # FEC           [*off/fc-fec/rs-fec/on (SFP:FC-FEC;QSFP:RS-FEC)]"
    echo "    # FLOODING      [*0/N (sec)]"
#    echo "    # Auto-Neg      [*off/on]"
    echo "    Ps. '*' means default setting"
    echo ""
    echo "    Ex: ./sdk_start.sh qsfp=100 sfp=25"
    echo "    Ex: ./sdk_start.sh qsfp=100 sfp=25 if=fiber vlan=on fec=rs-fec"
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
    elif [[ $input_item == "vlan" ]] || [[ $input_item == "VLAN" ]] || [[ $input_item == "vl" ]]; then
        if [[ $input_value == "on" ]] || [[ $input_value == "off" ]] || [[ $input_value == "single" ]]; then
            if [[ $input_value == "off" ]]; then
                sdk_vlan=0
            elif [[ $input_value == "on" ]]; then
                sdk_vlan=1
            elif [[ $input_value == "single" ]]; then
                sdk_vlan=2
            fi
            config_vlan=$sdk_vlan
            echo " # VLAN : $input_value"    ## for show/debug
        else
            echo "  Invalid VLAN setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "fec" ]] || [[ $input_item == "FEC" ]]; then
        if [[ $input_value == "off" ]] || [[ $input_value == "fc-fec" ]] || [[ $input_value == "rs-fec" ]] || [[ $input_value == "on" ]]; then
            if [[ $input_value == "off" ]]; then
                sdk_fec=0
            elif [[ $input_value == "fc-fec" ]]; then
                sdk_fec=1
            elif [[ $input_value == "rs-fec" ]]; then
                sdk_fec=2
            elif [[ $input_value == "on" ]]; then
                sdk_fec=3
            fi
            config_fec=$sdk_fec
            echo " # FEC : $input_value"    ## for show/debug
        else
            echo "  Invalid FEC setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "flooding" ]] || [[ $input_item == "FLOODING" ]]; then
        if (($input_value >= 0 )); then
            config_flooding=$input_value
            echo " # Flooding time : $input_value"    ## for show/debug
        else
            echo "  Invalid time setting!"
            Help_Input
            exit 1
        fi
    fi

    ## Output to configure file.
    echo "QSFP=$config_qsfp_speed" > $OUTPUT_FILE
    echo "SFP=$config_sfp_speed" >> $OUTPUT_FILE
    echo "INTERFACE=$config_interface" >> $OUTPUT_FILE
    echo "VLAN=$config_vlan" >> $OUTPUT_FILE
    echo "FEC=$config_fec" >> $OUTPUT_FILE
    echo "FLOODING=$config_flooding" >> $OUTPUT_FILE
#    echo "AN=$config_an" >> $OUTPUT_FILE
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
Input_Get $5
Input_Get $6

#cat $OUTPUT_FILE    ## for debug

## Execute SDK
/home/root/mfg/appDemo

