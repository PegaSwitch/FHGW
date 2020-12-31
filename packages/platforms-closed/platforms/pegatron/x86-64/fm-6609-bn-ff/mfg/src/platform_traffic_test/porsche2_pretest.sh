#!/bin/bash

##
# $1 SFP
# $2 QSFP
# $3 packet number per interation
# $4 iteration
##

MFG_WORK_DIR="/home/root/mfg"
FILE_FOLDER="$MFG_WORK_DIR/sdk_configuration"
outputFile_init="$FILE_FOLDER/pt_loopback_init.dsh"
outputFile_cfg="$FILE_FOLDER/pt_loopback_cfg.dsh"

if (( $# < 4 )); then
    echo " # please enter [SFP speed], [QSFP speed], [packet count] and [iteration]. "
    echo "   SFP : 25/10  ; QSFP : 100/50/40/25/10"
    echo "   EX: packet count 100 and iteration 5 will make total 500 packets. "
    exit 1
else
    if [[ ! -f "$FILE_FOLDER/cfg_backupOrig.dsh" ]]; then
        #echo " [debug] need to back up original cfg.dsh first"
        cp $MFG_WORK_DIR/cfg.dsh $FILE_FOLDER/cfg_backupOrig.dsh
        sync
    fi

    if [[ "$1" == "10" ]]; then
        if [[ "$2" == "100" ]]; then
            fileName="$FILE_FOLDER/cfg_10Gx48_100Gx6_loopbackModule.dsh"
            init_fileName="$FILE_FOLDER/init_10Gx48_100Gx6.dsh"
        #elif  [[ "$2" == "50" ]]; then
        #    fileName="$FILE_FOLDER/cfg_10Gx48_50Gx12.dsh"
        #    init_fileName="$FILE_FOLDER/init_10Gx48_50Gx12.dsh"
        elif  [[ "$2" == "40" ]]; then
            fileName="$FILE_FOLDER/cfg_10Gx48_40Gx6_loopbackModule.dsh"
            init_fileName="$FILE_FOLDER/init_10Gx48_40Gx6.dsh"
        #elif  [[ "$2" == "25" ]]; then
        #    fileName="$FILE_FOLDER/cfg_10Gx48_25Gx16.dsh"
        #    init_fileName="$FILE_FOLDER/init_10Gx48_25Gx16.dsh"
        #elif  [[ "$2" == "10" ]]; then
        #    fileName="$FILE_FOLDER/cfg_10Gx48_10Gx16.dsh"
        #    init_fileName="$FILE_FOLDER/init_10Gx48_10Gx16.dsh"
        else    # Depend on PT request, not support other speed.
            echo " # Not support speed matrix"
            exit 1
        fi
    else  ## $1 == 25
        #if [[ "$2" == "25" ]]; then
        #    fileName="$FILE_FOLDER/cfg_25Gx48_25Gx16.dsh"
        #    init_fileName="$FILE_FOLDER/init_25Gx48_25Gx16.dsh"
        #elif [[ "$2" == "10" ]]; then
        #    fileName="$FILE_FOLDER/cfg_25Gx48_10Gx16.dsh"
        #    init_fileName="$FILE_FOLDER/init_25Gx48_10Gx16.dsh"
        #elif [[ "$2" == "40" ]]; then
        if [[ "$2" == "40" ]]; then
            fileName="$FILE_FOLDER/cfg_25Gx48_40Gx6_loopbackModule.dsh"
            init_fileName="$FILE_FOLDER/init_25Gx48_40Gx6.dsh"
        #elif [[ "$2" == "50" ]]; then
        #    fileName="$FILE_FOLDER/cfg_25Gx48_50Gx12.dsh"
        #    init_fileName="$FILE_FOLDER/init_25Gx48_50Gx12.dsh"
        elif [[ "$2" == "100" ]]; then
            fileName="$FILE_FOLDER/cfg_25Gx48_100Gx6_loopbackModule.dsh"
            init_fileName="$FILE_FOLDER/init_25Gx48_100Gx6.dsh"
        else    # Depend on PT request, not support other speed.
            echo " # Not support speed matrix"
            exit 1
        fi
    fi

    case $2 in
        100|40)
            port_start_index=0
            port_end_index=53
            ;;
        #50)
        #    port_start_index=0
        #    port_end_index=59
        #    ;;
        #25|10)
        #    port_start_index=0
        #    port_end_index=63
        #    ;;
        *)  ;;
    esac

    if [[ ! -z "$3" && ! -z "$4" ]]; then
        packetNum=$3
        pktIteration=$4
    fi

    ## copy .cfg file to be called
    cp $fileName $outputFile_cfg
    sleep 1

    ## insert same init_ file to be exeute.
    # sed -i "1idiag load script name=$init_fileName" $outputFile_cfg
    cp $init_fileName $outputFile_init
    sleep 1

    sync

    echo "stat clear portlist=all" >> $outputFile_cfg
    echo "wait set delay=3" >> $outputFile_cfg

    if (( 0 )); then    ## 20190718 Jenny move this if-state up for FW upgrade regression test used, to support mac internal loopback traffic test.
        echo "port set property portlist=0-53 loopback=mac" >> $outputFile_cfg

        echo "wait set delay=3" >> $outputFile_cfg
        echo "pkt set rx init" >> $outputFile_cfg
        echo "wait set delay=3" >> $outputFile_cfg

        echo "test loopback mac unit=0 portlist=0-53 len=64 num=$packetNum iteration=$pktIteration" >> $outputFile_cfg
        echo "wait set delay=3" >> $outputFile_cfg
        echo "port show property portlist=all" >> $outputFile_cfg
        echo "wait set delay=3" >> $outputFile_cfg
    else
        ## assign each port a single vlan
        echo "diag load script name=$FILE_FOLDER/vlan_set_perport.dsh" >> $outputFile_cfg
        echo "wait set delay=3" >> $outputFile_cfg

        ## show vlan setting.
        echo "vlan show member" >> $outputFile_cfg
        echo "wait set delay=3" >> $outputFile_cfg

        ## show ports' status
        echo "port show property portlist=${port_start_index}-${port_end_index}" >> $outputFile_cfg
        echo "wait set delay=3" >> $outputFile_cfg

        ## send 100 256 pkt-length to per port
        for (( loop = 1; loop <= $pktIteration; loop += 1 ))
        do
            echo "pkt send tx portlist=${port_start_index}-${port_end_index} len=256 num=$packetNum dmac=00-00-00-00-00-01 smac=00-00-00-01-00-00 payload=0x08004501" >> $outputFile_cfg
        done

        ## restore vlan to default to stop pkt forwarding
        echo "diag load script name=$FILE_FOLDER/vlan_set_perport_default.dsh" >> $outputFile_cfg
        echo "wait set delay=3" >> $outputFile_cfg

    fi

    ## show ports' counter
    echo "stat show portlist=${port_start_index}-${port_end_index}" >> $outputFile_cfg
    echo "wait set delay=3" >> $outputFile_cfg

fi
