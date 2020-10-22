#!/bin/bash

##################
# $1 delay time
##################

MFG_WORK_DIR="/home/root/mfg"
FILE_FOLDER="$MFG_WORK_DIR/sdk_configuration"
outputFile_burnin_dsh="$FILE_FOLDER/burnin.dsh"

if (( $# < 1 )); then
    echo " # please enter [packet trasfer time long] in minute. "
    echo "   EX: ./pega_sources/pega_porsche2_create_ptBurninScript.sh 5"
    exit 1
else
    if [[ ! -f "$FILE_FOLDER/cfg_backupOrig.dsh" ]]; then
        # echo " [debug] need to back up original cfg.dsh first"
        cp $MFG_WORK_DIR/cfg.dsh $FILE_FOLDER/cfg_backupOrig.dsh
        sync
        sleep 1
        cp $FILE_FOLDER/cfg_25Gx48_100Gx6_loopbackModule.dsh $MFG_WORK_DIR/cfg.dsh
        sync
        sleep 1
    fi

    delay_sec=${1:-"1"}
    delay_sec=$(( $1 * 60 ))
    port_start_index=${2:-"0"}
    port_end_index=${3:-"53"}

    ## add short delay between commands
    echo "wait set delay=3" > $outputFile_burnin_dsh
    echo "stat clear portlist=all" >> $outputFile_burnin_dsh

    ## clear counter
    # echo "stat clear portlist=all" > $outputFile_burnin_dsh
    echo "wait set delay=3" >> $outputFile_burnin_dsh
    
    ## set vlan for per 2 ports.
    echo "diag load script name=$FILE_FOLDER/vlan_set.dsh" >> $outputFile_burnin_dsh
    echo "wait set delay=3" >> $outputFile_burnin_dsh
    
    ## show vlan setting.
    echo "vlan show member" >> $outputFile_burnin_dsh
    echo "wait set delay=3" >> $outputFile_burnin_dsh

    ## show ports' status
    echo "port show property portlist=${port_start_index}-${port_end_index}" >> $outputFile_burnin_dsh
    echo "wait set delay=3" >> $outputFile_burnin_dsh
    
    ## send 100 256 pkt-length to per port
    echo "pkt send tx portlist=${port_start_index}-${port_end_index} len=256 num=100 dmac=00-00-00-00-00-01 smac=00-00-00-01-00-00 payload=0x08004501" >> $outputFile_burnin_dsh

    ## STOP SDK FOR A WHILE to make packet loop
    echo "wait set delay=$delay_sec" >> $outputFile_burnin_dsh

    ## restore vlan to default to stop pkt forwarding
    echo "diag load script name=$FILE_FOLDER/vlan_set_default.dsh" >> $outputFile_burnin_dsh
    echo "wait set delay=3" >> $outputFile_burnin_dsh
    
    ## show ports' counter
    echo "stat show portlist=${port_start_index}-${port_end_index}" >> $outputFile_burnin_dsh
    echo "wait set delay=3" >> $outputFile_burnin_dsh
fi

