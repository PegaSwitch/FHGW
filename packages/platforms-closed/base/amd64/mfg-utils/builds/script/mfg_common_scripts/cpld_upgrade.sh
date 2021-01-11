#! /bin/bash

## variables defined ::
source ${HOME}/mfg/mfg_sources/platform_detect.sh

cpldCheck_filePath="/tmp/cpldCheck.txt"

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
        sleep $I2C_ACTION_DELAY
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

function Resume_GPIO_Setting ()
{
    ## unexport GPIO for safety
    if [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
        echo "197" > /sys/class/gpio/unexport    # GPIO-1
        echo "198" > /sys/class/gpio/unexport    # GPIO-2
        echo "199" > /sys/class/gpio/unexport    # GPIO-3
        echo "212" > /sys/class/gpio/unexport    # GPIO-16
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        if [[ "$board_sel" == "npu" ]]; then
            echo 0 > /sys/class/gpio/gpio461/value   # resume GPIO-25 value for JTAG
            echo "461" > /sys/class/gpio/unexport    # GPIO-25
            echo "448" > /sys/class/gpio/unexport    # GPIO-12
            echo "463" > /sys/class/gpio/unexport    # GPIO-27
            echo "497" > /sys/class/gpio/unexport    # GPIO-61
            echo "504" > /sys/class/gpio/unexport    # GPIO-68
        else
            echo "442" > /sys/class/gpio/unexport    # GPIO-6
            echo "460" > /sys/class/gpio/unexport    # GPIO-24
            echo "468" > /sys/class/gpio/unexport    # GPIO-32
            echo "486" > /sys/class/gpio/unexport    # GPIO-50
        fi
    fi
}

function Cpld_Upgrade()
{
    date

    if [[ -f "$cpldCheck_filePath" ]]; then
        rm $cpldCheck_filePath
        sleep 2
    fi

    cd $MFG_WORK_DIR/cpld_fw_upgrade

    ## GEMINI MB design difference, need seperate FW, so need detect version suitable or not.
    if [[ "$PROJECT_NAME" == "GEMINI" ]] && [[ "$board_sel" == "mb" ]]; then
        data_result=$( { Read_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_VER_REG ; } 2>&1 )
        mb_hw_ver=$(($data_result >> 5))
        if [[ "$fw_type" == "BURN" ]]; then
            if [[ "$mb_hw_ver" == "1" && "$fw_version" != "bac" ]] || (( $mb_hw_ver == 2 && $fw_ver_total <=3 )); then    ## e.g. bac=3 ; b2ac=4
                echo " # $_file_name is not support for this version main board !"

                Mutex_Clean
                if (( $FLAG_USE_IPMI == "$TRUE" )); then
                    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
                fi
                exit 1
            fi
        fi
    fi

    ## BUGATTI need to enable JTAG selection to CPU first.
    if [[ "$PROJECT_NAME" == "BUGATTI" ]] && [[ "$board_sel" == "mb" ]]; then
        ## set CPLD A Misc. control register 0x07 for cpu upgrade
        orig_data=$( { Read_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_MCR_REG ; } 2>&1 )
        data_cpu_en=$(( $orig_data | 0x20 ))                          # JTAG_EN_NPU_R [5] 0:header ; 1:CPU
        Write_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_MCR_REG $data_cpu_en

        echo "  += Set JTAG_EN_NPU to CPU mode : Done"
    fi

    ## JTAG bus setting , due to Denverton GPIO setting is wrapped in the excusion file so don't need additional calling here.
    if [[ "$SUPPORT_CPU" != "DENVERTON" ]]; then
        ./$executedFile    ## ./JTAG_gpio.sh
        echo "  += Set GPIO behavior : Done"
    fi

    ## CPLD firmware upgrade
    if [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
        ./cpld_upgrade_rangeley $upgrade_image
    elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        if [[ "$board_sel" == "npu" ]]; then
            ## Need to add board checking (with or without BMC) to decide FW is suitable or not !!!

            ## This is for BDX with BMC layout
            orig_bmcr1_data=$( { Read_I2C_Device_Node $I2C_BUS_ARBITER_AND_AFTER $NPU_CONTROL_CHIP_ADDR $CPLD_D_BMCR1_REG ; } 2>&1 )
            enable_cpu_jtag=$(( $orig_bmcr1_data | 0x01 ))
            Write_I2C_Device_Node $I2C_BUS_ARBITER_AND_AFTER $NPU_CONTROL_CHIP_ADDR $CPLD_D_BMCR1_REG $enable_cpu_jtag

            ./cpld_upgrade_bdxde_npu $upgrade_image |& tee -a $cpldCheck_filePath
        else
            ./cpld_upgrade_bdxde $upgrade_image |& tee -a $cpldCheck_filePath
        fi
    elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        ./cpld_upgrade_denverton $upgrade_image |& tee -a $cpldCheck_filePath
    fi

    cd $MFG_WORK_DIR

    ## BUGATTI need to restore JTAG selection
    if [[ "$PROJECT_NAME" == "BUGATTI" ]] && [[ "$board_sel" == "mb" ]]; then
        # set CPLD A Misc. control register back to original value
        Write_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_MCR_REG $orig_data
    fi

    ## close GPIO file node , due to Denverton GPIO setting is wrapped in the excusion file so don't need additional calling here.
    if [[ "$SUPPORT_CPU" != "DENVERTON" ]]; then
        ## This is for BDX with BMC layout
        if [[ "$board_sel" == "npu" ]]; then
            Write_I2C_Device_Node $I2C_BUS_ARBITER_AND_AFTER $NPU_CONTROL_CHIP_ADDR $CPLD_D_BMCR1_REG $orig_bmcr1_data
        fi

        Resume_GPIO_Setting
        echo "  += Resume GPIO behavior : Done"
    fi

    cpld_install_result=$( { cat $cpldCheck_filePath | grep "PASS!" ; } 2>&1 )
    if [[ ! -z "$cpld_install_result" ]]; then   # upgrade pass
        if [[ "$fw_version" == *"verify"* ]]; then
            echo ''
        else
            echo "Upgrade CPLD with '$upgrade_image' Done."
            echo ''
            if [[ "$fw_version" == *"refresh"* ]]; then
                echo "Please 'reboot' system to re-init configuration of CPLD registers as platform default setting."
            else
                if [[ "$board_sel" == "npu" ]]; then
                    echo "Please keep doing upgrade with refrash-mode vme file to load new NPU CPLD code."
                    echo "  ex: ./mfg_sources/cpld_upgrade.sh npu $MFG_WORK_DIR/cpld_fw_upgrade/bdxde-refresh-r02.vme"
                else
                    echo "Please keep doing upgrade with refrash-mode vme file to load new MB CPLD code."
                    echo "  ex: ./mfg_sources/cpld_upgrade.sh mb $MFG_WORK_DIR/cpld_fw_upgrade/mb-refresh_3cpld-20200729.vme"
                fi
                echo ""
            fi
        fi
    fi

    date
}

function Parsing_FileName()
{
    ## format : Project-Ver-Date

    if [[ "$1" == *"/"* ]]; then
        sub_file_name=$( ls $1 | rev | cut -d '/' -f 1 | rev )
        _file_name=$sub_file_name
    fi

    underline_cnt=0
    substr_start=1

    fNameLen=$(expr length $_file_name)

    for (( i = 1 ; i <= $fNameLen ; i += 1 ))
    do
        str=$(expr substr $_file_name $i 1)

        if [ "$str" == "-" ] || [ "$str" == "." ]; then
            dash_cnt=$(( $dash_cnt + 1 ))
            substr_end=$i
            fNameSubStr=$(expr substr $_file_name $substr_start $(( $substr_end - $substr_start )))
            # echo "$dash_cnt : $fNameSubStr --- index $substr_start to $substr_end"

            case $dash_cnt in
            1)
                printf "Project Name => %s\n" $fNameSubStr
                ;;
            2)
                printf "Version      => %s\n" $fNameSubStr
                fw_version=$fNameSubStr

                if [[ "$fw_version" == *"verify"* ]] || [[ "$fw_version" == *"refresh"* ]]; then
                    fw_type="CHECK"
                else
                    fw_type="BURN"
                    ## Get all alpha characters and cut new line characters.
                    chars=$(echo "$fw_version" | grep -io '[a-z2-9]' | tr -d '\n')
                    ## Count total alpha characters.
                    fw_ver_total=$(echo -n "$chars" | wc -m)
                    # echo $fw_ver_total    ## e.g. bac=3 ; b2ac=4
                fi
                ;;
            3)
                printf "Release Date => %s\n" $fNameSubStr
                rel_date=$fNameSubStr
                ;;
            *) ;;
            esac

            if (( $dash_cnt == 3 )); then
                # printf "CPLD Firmware Version => %s -- %s\n" $fw_version $rel_date
                break
            fi

            substr_start=$(( $substr_end + 1 ))
        fi
    done
}

function Image_Existance_Check()
{
    input_image=$1
    if [ -z $input_image ]; then
        return
    fi
    if [ -e $input_image ]; then
        upgrade_image=$input_image
        Parsing_FileName $upgrade_image
    else
       echo ""
       echo "File '$input_image' NOT exist!"
       echo ""
       exit 1
    fi
}

function Board_Selection()
{
    if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        if [[ "$1" == "npu" ]]; then
            board_sel="npu"
            executedFile="JTAG_gpio_BDXDE_NPU.sh"
        else # == mb
            board_sel="mb"
            executedFile="JTAG_gpio_BDXDE.sh"
        fi
    elif [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
        board_sel="mb"
        executedFile="JTAG_gpio_Rangeley.sh"
    elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        board_sel="mb"
        # executedFile="JTAG_gpio.sh"   # NO needed for Denverton !
    fi
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

function Help_Message()
{
    echo ""
    echo "  [MFG] CPLD upgrade help message:"
    echo "    Ex: ./cpld_upgrade"
    echo "    Ex: ./cpld_upgrade [npu/mb] [upgrade_image] with full directly path"
    echo "    Ex: ./cpld_upgrade mb $MFG_WORK_DIR/cpld_fw_upgrade/bugatti2-b8a4c4-20190111.vme"
    echo "    Ex: ./cpld_upgrade npu $MFG_WORK_DIR/cpld_fw_upgrade/BDXDE-bgmode-r03.vme"
    echo ""
}

function Input_Help()
{
    input_string=$1

    if [[ -z "$input_string" ]] || [[ $input_string == "-h" ]] || [[ $input_string == "-help" ]] || [[ $input_string == "--h" ]] ||
       [[ $input_string == "--help" ]] || [[ $input_string == "?" ]]; then
        Help_Message
        exit 1
    fi
}

#
# Main
#
Input_Help $1
Image_Existance_Check $2

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

Board_Selection $1
Cpld_Upgrade

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
