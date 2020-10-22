#! /bin/bash

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

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

function Get_Model_Name()
{
    model_name=$( { onie_syseeprom -g $ONIE_PRODUCTNAME_TYPECODE ; } 2>&1 )
    echo "  Model name:" $model_name
}

function Get_CPU_Info()
{
    core_num=$( cat /proc/cpuinfo | grep "processor" | wc -l )
    cpu_name=$( cat /proc/cpuinfo | grep -m 1 "model name" | cut -c14- )
    printf '  CPU: %d-core, ' $core_num
    echo $cpu_name
}

function Get_DDR_Info()
{
    ddr_size=$( cat /proc/meminfo | grep "MemTotal" | cut -c17-24 )
    size_GB=$(echo "scale=3; $ddr_size / 1024 / 1024 / 1" | bc)
    printf '  DDR: %.2f GB (%d kB)\n' $size_GB $ddr_size
}

function Get_Storage_Info()
{
    emmc_label="Generic-"    # eMMC label = Generic-_Multiple_Reader
    ssd_label="ATA"

    ssd_name=$( lsscsi -s | grep "\b$ssd_label\b" | cut -c30-45 )
    if [[ ! -z "$ssd_name" ]]; then
        ssd_size=$( lsscsi -s | grep "\b$ssd_label\b" | cut -c65- )
        echo "  SSD:" $ssd_name "," $ssd_size
    fi

    emmc_name=$( lsscsi -s | grep $emmc_label | cut -c30-45 )
    emmc_size=$( lsscsi -s | grep $emmc_label | cut -c65- )
    if [[ ! -z "$emmc_size" ]]; then
        echo "  eMMC:" $emmc_name "," $emmc_size
    fi

    # to discard ssd and emmc info, so rest are usb info.
    amount=$( lsscsi -s | sed "/\b$ssd_label\b/d" | sed "/$emmc_label/d" | wc -l )
    while [ $amount != 0 ]
    do
        orderRow=$amount
        orderRow+="p"

        usb_name=$( lsscsi -s | sed "/\b$ssd_label\b/d" | sed "/$emmc_label/d" | sed -n "$orderRow" | cut -c21-45 )
        usb_size=$( lsscsi -s | sed "/\b$ssd_label\b/d" | sed "/$emmc_label/d" | sed -n "$orderRow" | cut -c65- )
        echo "  USB:" $usb_name "," $usb_size
        amount=$(( amount - 1))
    done
}

function Get_MAC_Info()
{
    location=$( { lspci | grep "01:00.0" | cut -d ' ' -f 1 ; } 2>&1 )
    MAC_device=$( lspci -s $location -vvv | sed -n "1p" | cut -c29- )
    MAC_speed=$( { lspci -s $location -vvv | grep "LnkSta" | sed -n "1p" | cut -d ',' -f 1 | cut -c3- ; } 2>&1 )
    MAC_width=$( { lspci -s $location -vvv| grep "LnkSta" | sed -n "1p" | cut -d ',' -f 2 ; } 2>&1 )
    printf '  MAC: '
    echo $MAC_device "," $MAC_speed "," $MAC_width
}

function Get_HW_Info()
{
    ## BY NPU boot code to show info
    if [[ "$SUPPORT_CPU" == "BDXDE" ]];then
        ## CPLD
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $CPLD_VER_REG; } 2>&1 )
        hw_ver=$(($data_result >> 5))
        board_revision_bit=$( { echo "obase=2;$hw_ver" | bc ; } 2>&1 )
        if (( 0 )); then    ## This case is for old (short) BDX only, because old CPLD NOT detect HW revision pin ...
            if [[ "$board_revision_bit" == "1" ]]; then     #001
                board_revision="1.00"
            elif [[ "$board_revision_bit" == "10" ]]; then  #010
                board_revision="2.00"
            elif [[ "$board_revision_bit" == "11" ]]; then  #011
                board_revision="3.00"
            else
                board_revision="??"
            fi
            echo "  NPU Board : BDX-DE_NPU REV." $board_revision
        else
            if [[ "$board_revision_bit" == "0" ]]; then     #000
                board_revision="BDX-DE_NPU REV. 2.00"
            elif [[ "$board_revision_bit" == "1" ]]; then   #001
                board_revision="BDX-DE-BMC_NPU REV. 1.00"
            elif [[ "$board_revision_bit" == "10" ]]; then  #010
                board_revision="BDX-DE-BMC_NPU REV. 1.10"
            else
                board_revision="??"
            fi
            echo "  NPU Board :" $board_revision
        fi
    elif [[ "$SUPPORT_CPU" == "DENVERTON" ]];then
        ## MCU
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x1 ; } 2>&1 )
        # hw_ver=$(($data_result >> 4 ))        ## This is wrong but suitable for MCU v06.
        hw_ver=$(($data_result & 0x0f ))        ## For v07
        if [[ "$hw_ver" == "2" ]]; then   #0010
            board_revision="1.00"
        elif [[ "$hw_ver" == "3" ]]; then   #0011
            board_revision="1.10"
        else
            board_revision=$hw_ver".00"
        fi
        echo "  NPU Board : DNV-NS_NPU REV." $board_revision
    fi

    ## MB board ID - by NPU GPIO
    ## MB HW version - by CPLD "A" to detect version
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR $CPLD_VER_REG ; } 2>&1 )
    hw_ver=$(($data_result >> 5))
    case $hw_ver in
        # 0) board_version="1.00";;
        1) board_version="1.00";;
        2) board_version="2.00";;
        3) board_version="3.00";;
        *) board_version="??";;
    esac
    ## For special case
    if [[ "$PROJECT_NAME" == "PORSCHE" ]] && [[ "$hw_ver" == "3" ]]; then
        echo "  Main Board : PORSCHE2 REV. 1.00"
    elif [[ "$PROJECT_NAME" == "GEMINI" ]] && [[ "$hw_ver" == "3" ]]; then
        echo "  Main Board : GEMINI REV. 2.00A"
    elif [[ "$PROJECT_NAME" == "GEMINI" ]] && [[ "$hw_ver" == "4" ]]; then
        echo "  Main Board : GEMINI REV. 3.00"
    else
        echo "  Main Board :" $PROJECT_NAME "REV." $board_version
    fi

    ## by FB MCU to detect fan board HW version
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $FB_MCU_HW_VERSION_REG; } 2>&1 )
    data_expander=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR 0x58 ; } 2>&1 )
    check_ioexpander_alert=$(( $data_expander & 0x40 >> 6 ))
    if (( $check_ioexpander_alert == 1 )); then    # io_expander (0x3a) NOT exist
        pcbVer=$(((data_result & 0xe0) >> 5))
        pcbVer_bit=$( { echo "obase=2;$pcbVer" | bc ; } 2>&1 )
        if [[ "$pcbVer_bit" == "0" ]]; then   #000
            PCB_ver_id="JAGUAR_FC_BOARD_R1.00"
        elif [[ "$pcbVer_bit" == "1" ]]; then  #001
            PCB_ver_id="JAGUAR_FC_BOARD_R2.00"
        elif [[ "$pcbVer_bit" == "10" ]]; then  #010
            PCB_ver_id="5X40MM_FC_DB_R1.00"
        else
            PCB_ver_id="??"
        fi

        sysVer=$(((data_result & 0x1c) >> 2))
        sysVer_bit=$( { echo "obase=2;$sysVer" | bc ; } 2>&1 )
        if [[ "$sysVer_bit" == "0" ]]; then   #000 (0)
            SYS_id=""
        elif [[ "$sysVer_bit" == "10" ]]; then  #010 (2)
            SYS_id="Taurus"
        elif [[ "$sysVer_bit" == "11" ]]; then  #011 (3)
            SYS_id="Aston Martin"
        else
            SYS_id="??"
        fi

        typeVer=$((data_result & 0x03 ))
        typeVer_bit=$( { echo "obase=2;$typeVer" | bc ; } 2>&1 )
        if [[ "$typeVer_bit" == "0" ]]; then   #00
            type_id="Fan Module x5"
        elif [[ "$typeVer_bit" == "1" ]]; then   #01
            type_id="Fan Module x6"
        elif [[ "$typeVer_bit" == "10" ]]; then
            type_id="Fan Module x4"
        else
            type_id="??"
        fi

        echo "  Fan Board :" $PCB_ver_id $SYS_id "," $type_id
    else
        pcbVer=$(((data_result & 0xe0) >> 5))
        pcbVer_bit=$( { echo "obase=2;$pcbVer" | bc ; } 2>&1 )
        if [[ "$pcbVer_bit" == "0" ]]; then   #000
            PCB_ver_id="REV:1.00"
        elif [[ "$pcbVer_bit" == "1" ]]; then  #001
            PCB_ver_id="REV:2.00"
        elif [[ "$pcbVer_bit" == "10" ]]; then  #010
            PCB_ver_id="REV:3.00"
        elif [[ "$pcbVer_bit" == "11" ]]; then  #011
            PCB_ver_id="REV:4.00"
        else
            PCB_ver_id="??"
        fi
        typeVer=$((data_result & 0x1f ))
        typeVer_bit=$( { echo "obase=2;$typeVer" | bc ; } 2>&1 )
        if [[ "$typeVer_bit" == "0" ]]; then
            type_id="Maximum 5pcs Fan Modules"
        elif [[ "$typeVer_bit" == "1" ]]; then
            type_id="Maximum 6pcs Fan Modules"
        elif [[ "$typeVer_bit" == "10" ]]; then
            type_id="Maximum 4pcs Fan Modules"
        elif [[ "$typeVer_bit" == "11" ]]; then
            type_id="Maximum 3pcs Fan Modules"
        else
            type_id="??"
        fi

        sysVer=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR 0x6 ; } 2>&1 )
        if [[ "$sysVer" == "0x00" ]]; then
            SYS_id="5X40MM_FC_DB"
        elif [[ "$sysVer" == "0x02" ]]; then
            SYS_id="TAURUS_FC"
        elif [[ "$sysVer" == "0x03" ]]; then
            SYS_id="6X40MM_FC_DB"
        else
            SYS_id="??"
        fi

        echo "  Fan Board :" $SYS_id $PCB_ver_id "," $type_id
    fi
}

function Get_Linux_Version()
{
    linux_ver=$( cat /proc/version | cut -c15-40 )
    printf '  Linux: '
    echo $linux_ver
}

function Get_SDK_FW_Version()
{
    if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        echo "  MFG: Bugatti2_BDXDE_1.4.5"
        echo "  SDK: broadcom sdk-xgs-robo-6.5.13"
        tmp_file="/home/root/bg_sdkStart.txt"
        if [[ -f $tmp_file ]]; then
            pcie_loader_version=$( { cat $tmp_file | grep "PCIe FW" | sed -n "1p" | cut -c2- ; } 2>&1 )
            if [[ -z "$pcie_loader_version" ]]; then
                pcie_loader_version="PCIe FW loader version: 2.5"
            fi
            echo "  "$pcie_loader_version
            pcie_fw_version=$( { cat $tmp_file | grep "PCIe FW" | sed -n "2p" | cut -c2- ; } 2>&1 )
            if [[ -z "$pcie_fw_version" ]]; then
                pcie_fw_version="PCIe FW version: D102_08"
            fi
            echo "  "$pcie_fw_version
        fi
    elif [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        echo "  MFG: Porsche 2 v0.0.19"
        echo "  SDK: NPS 2.0.6"
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        echo "  MFG: Jaguar with Broadwell-DE --- v0.0.6"
        echo "  SDK: broadcom sdk-xgs-robo-6.5.13"
    elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
        # echo "  MFG: Aston Martin v0.0.1"
        echo " ## not implement yet !!!"  #############################################
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        echo "  MFG: Gemini v0.1.3"
        echo "  SDK: Marvell CPSS 4.2.2020.3"
    fi
}

function Get_CPLD_FW_Version()
{
    # CPLD A
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR $CPLD_VER_REG; } 2>&1 )
    fw_ver=$(($data_result & 0x1f))
    ## bit-flag to declare verified or formal release version, by EE declared.
    if (( ( $data_result & 0x10 ) >> 4 == 1 )); then
        fw_ver=$(($data_result & 0x0f))
        fw_ver=$fw_ver"_test"
    fi

    hw_ver=$(($data_result >> 5))
    echo "  CPLD A (MB) - FW ver:" $fw_ver " (HW ver value:" $hw_ver ")"

    # CPLD B
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_1
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_B_ADDR $CPLD_VER_REG; } 2>&1 )
    fw_ver=$(($data_result & 0x1f))
    ## bit-flag to declare verified or formal release version, by EE declared.
    if (( ( $data_result & 0x10 ) >> 4 == 1 )); then
        fw_ver=$(($data_result & 0x0f))
        fw_ver=$fw_ver"_test"
    fi

    hw_ver=$(($data_result >> 5))
    echo "  CPLD B (MB) - FW ver:" $fw_ver " (HW ver value:" $hw_ver ")"

    # CPLD C
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_2
    data_result=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_C_ADDR $CPLD_VER_REG; } 2>&1 )
    fw_ver=$(($data_result & 0x1f))
    ## bit-flag to declare verified or formal release version, by EE declared.
    if (( ( $data_result & 0x10 ) >> 4 == 1 )); then
        fw_ver=$(($data_result & 0x0f))
        fw_ver=$fw_ver"_test"
    fi

    hw_ver=$(($data_result >> 5))
    echo "  CPLD C (MB) - FW ver:" $fw_ver " (HW ver value:" $hw_ver ")"

    # Resume CPLD bus
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG 0x0
}

function Get_MCU_FW_Version()
{
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_A $I2C_MUX_REG $I2C_MUX_CHANNEL_MCU

    for (( mcu = 0 ; mcu < $MCU_AMOUNT ; mcu += 1 ))
    do
        mcu_index=$(($MB_MCU_SW_VERSION_REG | $mcu))
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $mcu_index; } 2>&1 )
        mainVer=$(($data_result >> 4))
        subVer=$(($data_result & 0x0f))

        board_index=$(($MB_MCU_HW_VERSION_REG | $mcu))
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $MB_MCU_ADDR $board_index; } 2>&1 )
        board_ID=$(($data_result & 0x1f))
        board_ID_bit=$( { echo "obase=2;$board_ID" | bc ; } 2>&1 )

        if (( $mcu == 0x0 )); then
            if [[ "$board_ID_bit" == "11" ]]; then   #00011
                board_ID="PORSCHE"
            elif [[ "$board_ID_bit" == "100" ]]; then   #00100
                board_ID="BUGATTI"
            elif [[ "$board_ID_bit" == "101" ]]; then   #00101
                board_ID="JAGUAR"
            elif [[ "$board_ID_bit" == "1000" ]]; then   #01000
                board_ID="ASTON_MARTIN"
            elif [[ "$board_ID_bit" == "1001" ]]; then   #01001
                board_ID="GEMINI"
            else
                board_ID="??"
            fi
            printf '  MCU - Main Board: %s (%05d), ver. %c.%c \n' $board_ID $board_ID_bit $mainVer $subVer
        else
            printf '  MCU - Fan  Board: ver. %c.%c \n' $mainVer $subVer
        fi
    done
}

function Get_PMBus_Version()
{
    declare -a array_pmbus

    ## get FW checksum of TPS53679 checksum on NPU.
    data=$( { i2cdump -y $I2C_BUS $PMBUS_NPU_63_ADDR s $PMBUS_NVM_CHECKSUM_REG ; } 2>&1 )
    for (( i = 0 , j = 2 ; i < 4 ; i++, j=i+2 ))
    do
        array_pmbus[i]=$( { echo $data | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    done
    echo "  PMBus FW checksum (NPU 0x63) : 0x"${array_pmbus[0]}${array_pmbus[1]}${array_pmbus[2]}${array_pmbus[3]}

    data=$( { i2cdump -y $I2C_BUS $PMBUS_NPU_64_ADDR s $PMBUS_NVM_CHECKSUM_REG ; } 2>&1 )
    for (( i = 0 , j = 2 ; i < 4 ; i++, j=i+2 ))
    do
        array_pmbus[i]=$( { echo $data | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    done
    echo "  PMBus FW checksum (NPU 0x64) : 0x"${array_pmbus[0]}${array_pmbus[1]}${array_pmbus[2]}${array_pmbus[3]}


    ## switch VDD_CORE voltage regulator (PSMCR) to CPU path, before get MB PMBus data, for some platform design.
    if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then    ## (0xf of CPLD-A)
        Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
        Write_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR 0xf 0x1
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then   ## (0x14 of CPLD-B)
        Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_1
        Write_I2C_Device_Node $I2C_BUS $CPLD_B_ADDR 0x14 0x1
    fi

    ## get PMBUS data
    ## 20200921 Due to BMC v3 (IPMI) not support MUX channel switch, so need to use I2C commands instead.
    i2cset -y $I2C_BUS $I2C_MUX_PMBUS $I2C_MUX_REG $I2C_MUX_CHANNEL_PMBUS
    usleep $I2C_ACTION_DELAY
    ## Modify End

    data=$( { i2cdump -y $I2C_BUS $PMBUS_MB_A_ADDR s $PMBUS_NVM_CHECKSUM_REG ; } 2>&1 )
    for (( i = 0 , j = 2 ; i < 4 ; i++, j=i+2 ))
    do
        array_pmbus[i]=$( { echo $data | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
    done

    echo "  PMBus FW checksum (MB  $PMBUS_MB_A_ADDR) : 0x"${array_pmbus[0]}${array_pmbus[1]}${array_pmbus[2]}${array_pmbus[3]}

    # Special case for additional 3rd TP53679 of Gemini.
    if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        data=$( { i2cdump -y $I2C_BUS $PMBUS_MB_C_ADDR s $PMBUS_NVM_CHECKSUM_REG ; } 2>&1 )
        for (( i = 0 , j = 2 ; i < 4 ; i++, j=i+2 ))
        do
            array_pmbus[i]=$( { echo $data | cut -d ':' -f 2 | cut -d ' ' -f $j ; } 2>&1 )
        done
        echo "  PMBus FW checksum (MB  $PMBUS_MB_C_ADDR) : 0x"${array_pmbus[0]}${array_pmbus[1]}${array_pmbus[2]}${array_pmbus[3]}
    fi

    ## restore PSMCR value to default.
    if [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
        Write_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR 0xf 0x0
    elif [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_1
        Write_I2C_Device_Node $I2C_BUS $CPLD_B_ADDR 0x14 0x0
    fi
}

function Get_NPU_FW_Version()
{
    if [[ "$SUPPORT_CPU" == "BDXDE" ]];then
        ## CPLD
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $CPLD_VER_REG; } 2>&1 )
        fw_ver=$(( $data_result & 0x1f ))
        if (( $fw_ver > 7 ));then        ## ver8 or later has bit-flag to declare verified or formal release version, by EE declared.
            bit_formal_or_test=$(( ( $fw_ver & 0x10 ) >> 4 ))
            if (( $bit_formal_or_test == 0 )); then    ## formal version
                fw_ver=$(( $data_result & 0x0f ))
            else                                       ## internal verified version
                fw_ver=$(( $data_result & 0x0f ))
                fw_ver=$fw_ver"_test"
            fi
        fi
        hw_ver=$(( $data_result >> 5 ))
        echo "  CPLD  (NPU) - FW ver:" $fw_ver " (HW ver value:" $hw_ver ")"
    else
        ## MCU
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x0 ; } 2>&1 )
        npu_mcu_fw_ver_man=$(( ( $data_result & 0xf0 ) >> 4 ))
        npu_mcu_fw_ver_sub=$(( $data_result & 0x0f ))
        printf '  MCU - NPU  Board: ver. %c.%c \n' $npu_mcu_fw_ver_man $npu_mcu_fw_ver_sub
    fi
}

function I2C_Mutex_Check_And_Create()
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

function I2C_Mutex_Clean()
{
    rm $I2C_MUTEX_NODE
    sync
    usleep 100000
}

I2C_Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

echo ""
echo "Hardware Information"
Get_Model_Name
Get_CPU_Info
Get_MAC_Info
Get_DDR_Info
Get_Storage_Info
Get_HW_Info
echo ""
echo "Firmware Version"
Get_SDK_FW_Version
Get_Linux_Version
Get_CPLD_FW_Version
Get_NPU_FW_Version
Get_MCU_FW_Version
Get_PMBus_Version
echo ""

I2C_Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
