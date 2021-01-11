#! /bin/bash

# Editor  : Julia, Jenny
# Purpose : This script is to upgrade main/fan board MCU firmware.
# NOTE    : New project need to add Hitless setting in HW_Reset_Pin_Control() !!!

## variables defined ::
source ${HOME}/mfg/mfg_sources/platform_detect.sh

{
    ## UART Selection
    MB_MCU_UART_SEL=0x1
    FB_MCU_UART_SEL=0x0

    ## MCU Registers
    MB_MCU_FW_UPGRADE_REG=0x0        # Main Board MCU Firmware Upgrade Register
    FB_MCU_FW_UPGRADE_REG=0x1        # FanBoard MCU Firmware Upgrade Register
    MCU_FW_UPGRADE_ENABLE=0xA5       # MCU Firmware Upgrade Write to Register Value
    MB_MCU_ALERT_REG=0x58
    MB_MCU_ALERT_FB_NOT_EXIST_BIT=0x01   # bit 0

    ## CPLD Registers, only for PORSCHE used.
    CPLD_B_POWER_CIRCUIT_REG=0x13

    ## Error Message Code
    ERR_MSG_SEL_BOARD_FAIL=1           # Select Board-Type parameter NOT mb or fb.
    ERR_MSG_IN_FILE_EMPTY=2
    ERR_MSG_IN_FILE_NOT_EXIST=3
    ERR_MSG_IN_FILE_CHOOSE_WRONG=4     # The Board-Type parameter NOT match the input MCU firmware.
    ERR_MSG_CHECKSUM_FAIL=5
    ERR_MSG_DEVICE_NOT_DETECT=6
    ERR_MSG_ASSIGN_GPIO_TO_UART_FAIL=7 # CPU GPIO assign to UART functional pin fail.

    # Delay Time
    CMD_DELAY_TIME=0.03                        # (unit: sec)
    MCU_UPGRADE_DELAY_TIME=1                   # (unit: sec)
    MCU_ENTER_BOOTLOADER_DELAY_TIME=0.3        # (unit: sec)
    MCU_MB_POLLING_FB_DELAY_TIME=2             # (unit: sec)
}

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
        ipmi_value_toHex=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 2)))" ; } 2>&1 )    # orig value format is " XX" , so just get XX then transform as 0xXX format.
        echo $ipmi_value_toHex    # this line is to make return with value 0xXX
        return
    fi
}

function I2C_Device_Detect()
{
    i2c_bus=$1
    i2c_device=$2

    ## Check Device Exist
    result=$( { i2cdetect -y $i2c_bus; } 2>&1 )
    sleep 0.001

    ## Get last match sub-string of string(i2c_device) after specified character(x).
    i2c_device_num=${i2c_device##*x}
    #echo "[MFG Debug] i2c_device_num ---> $i2c_device_num"
    if [[ $result != *"$i2c_device_num"* ]]; then
        device_exist_check=$FAIL
        return
    else
        device_exist_check=$SUCCESS
    fi
}

function Compare_Checksum()
{
    _file_name=$1

    ## Get part of checksum from file name
    checksum_from_fileName=$( expr substr $_file_name $checksum_start 32 )
    #printf "checksum from file name => %s\n" $checksum_from_fileName

    ## Calculate MD5 checksum from input file
    checksum=$( md5sum $_file_name | awk '{ print $1 }' )    # Select parameter 1

    ## Get part of checksum from file
    checksum_from_file=$( expr substr $checksum 1 32 )
    #printf "checkSum from file => %s\n" $checksum_from_file

    if [[ "$checksum_from_fileName" == "$checksum_from_file" ]]; then
        checksum_check=$SUCCESS
    else
        checksum_check=$FAIL
    fi
}

function HW_Reset_Pin_Control()
{
    action=$1    # reset / restore

    ## Control Reset Pin via CPLD
    case "$PROJECT_NAME" in
        "MERCEDES")
            i2c_bus=$I2C_BUS_MUX_B_CHANNEL_1
            cpld_addr=$CPLD_B_ADDR
            cpld_rst_reg=0x11
            if [[ "$action" == "reset" ]]; then
                cpld_rst_mcu=0x07        # Reset MCU by set 3rd bit to 0. (0x07 -> 0000_0111)
            else
                cpld_rst_mcu=0x0f
            fi
            ;;
        "BUGATTI")
            i2c_bus=$I2C_BUS_MUX_B_CHANNEL_0
            cpld_addr=$CPLD_A_ADDR
            cpld_rst_reg=0x04
            if [[ "$action" == "reset" ]]; then
                if [[ "$_board_type" == "mb" ]]; then
                    cpld_rst_mcu=0x37    # Reset MCU by set 3rd bit to 0. (0x37 -> 0011_0111)
                else  # fb
                    cpld_rst_mcu=0x1f    # Reset MCU by set 5th bit to 0. (0x1f -> 0001_1111)
                fi
            else
                cpld_rst_mcu=0x3f
            fi
            ;;
        "PORSCHE"|"JAGUAR")
            i2c_bus=$I2C_BUS_MUX_B_CHANNEL_1
            cpld_addr=$CPLD_B_ADDR
            cpld_rst_reg=0x11
            if [[ "$action" == "reset" ]]; then
                cpld_rst_mcu=0x17        # Reset MCU by set 3rd bit to 0. (0x17 -> 0001_0111)
            else
                cpld_rst_mcu=0x1f
            fi
            ;;
        "GEMINI")
            i2c_bus=$I2C_BUS_MUX_B_CHANNEL_1
            cpld_addr=$CPLD_B_ADDR
            cpld_rst_reg=0x11
            if [[ "$action" == "reset" ]]; then
                if [[ "$_board_type" == "mb" ]]; then
                    cpld_rst_mcu=0x0f    # Reset MCU by set 4th bit to 0. (0x37 -> 0000_1111)
                else  # fb
                    cpld_rst_mcu=0x17    # Reset MCU by set 3th bit to 0. (0x1f -> 0001_0111)
                fi
            else
                cpld_rst_mcu=0x1f
            fi
            ;;
        "ASTON")
            i2c_bus=$I2C_BUS_MUX_B_CHANNEL_0
            cpld_addr=$CPLD_A_ADDR
            cpld_rst_reg=0x21
            if [[ "$action" == "reset" ]]; then
                if [[ "$_board_type" == "mb" ]]; then
                    cpld_rst_mcu=0xf7   # Reset main board MCU by set 3rd bit to 0.
                                        # default value: 0xd3
                elif [[ "$_board_type" == "fb" ]]; then
                    cpld_rst_mcu=0xdf   # Reset fan board MCU by set 5th bit to 0.
                fi
            elif [[ "$action" == "restore" ]]; then
                cpld_rst_mcu=0xff
            fi
            ;;
        "FHGW")
            i2c_bus=$I2C_BUS_MUX_B_CHANNEL_1
            cpld_addr=$CPLD_B_ADDR
            cpld_rst_reg=0x0d
            if [[ "$action" == "reset" ]]; then
                if [[ "$_board_type" == "mb" ]]; then
                    cpld_rst_mcu=0xef    # Reset MCU by set 4th bit to 0. (0xff -> 1110_1111)
                else  # fb
                    cpld_rst_mcu=0xf7    # Reset MCU by set 3th bit to 0. (0xff -> 1111_0111)
                fi
            else
                cpld_rst_mcu=0xff
            fi
            ;;
        *)
            printf "\n[MFG Error Msg] Current project NOT support yet !!!\n"
            exit 1
            ;;
    esac

    Write_I2C_Device_Node $i2c_bus $cpld_addr $cpld_rst_reg $cpld_rst_mcu
}

function HW_Hitless_Pin_Control()
{
    value=$1

    # Pull Hitless Pin to Low via CPU
    case "$SUPPORT_CPU" in
        "RANGELEY")
            echo "[MFG Warning Msg] Pull Hitless NOT supported yet !!!"
            ;;
        "BDXDE")
            # GPIO(65) - Hitless
            echo 501 > /sys/class/gpio/export
            sleep $CMD_DELAY_TIME
            if [[ "$value" == "low" ]]; then
                echo 0 > /sys/class/gpio/gpio501/value
            elif [[ "$value" == "high" ]]; then
                echo 1 > /sys/class/gpio/gpio501/value
            fi
            sleep $CMD_DELAY_TIME
            echo 501 > /sys/class/gpio/unexport
            sleep $CMD_DELAY_TIME
            ;;
        "DENVERTON")
            # GPIO(38) - Hitless . [0]:High(1)/Low(0)
            if [[ "$value" == "low" ]]; then
                /sbin/gpio w 38 0x45000200
            elif [[ "$value" == "high" ]]; then
                /sbin/gpio w 38 0x45000201
            fi
            sleep $CMD_DELAY_TIME
            ;;
        *)
            echo "[Msg] Current CPU model NOT support yet !!!"
            # exit 1
            ;;
    esac
}

function CPU_UART_Setting()
{
    _board_type=$1

    case "$SUPPORT_CPU" in
        "RANGELEY")    cpu_gpio_uart="254" ;;
        "BDXDE")       cpu_gpio_uart="490" ;;
        *)  ;;
    esac

    if [[ "$SUPPORT_CPU" == "RANGELEY" ]] || [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
            if [[ ! -f "/sys/class/gpio/gpio453/" ]]; then
                echo "453" > /sys/class/gpio/export
            fi
            gpio_dir_17=$( { cat /sys/class/gpio/gpio453/direction ; } 2>&1 )
            if [[ -f "/sys/class/gpio/gpio453/" ]]; then
                echo "453" > /sys/class/gpio/unexport
            fi
            if [[ ! -f "/sys/class/gpio/gpio490/" ]]; then
                echo "490" > /sys/class/gpio/export
            fi
            gpio_dir_54=$( { cat /sys/class/gpio/gpio490/direction ; } 2>&1 )
            if [[ -f "/sys/class/gpio/gpio490/" ]]; then
                echo "490" > /sys/class/gpio/unexport
            fi

            #if (( $gpio_dir_17 != 0 || $gpio_dir_54 != 0 )); then    ## all as output pin
            if [[ "$gpio_dir_17" != "out" || "$gpio_dir_54" != "out" ]]; then    ## all as output pin
                echo " Default GPIO configure is fail ( GPIO_17 = $gpio_dir_17 ; GPIO_54 = $gpio_dir_54 ), please confirm procees before doing MCU FW upgrade !!!"
                exit 1
            else
                ## BDX-DE v2.0 add "UART to I2C Bridge" (GPIO-17) default(I2C used):1 ; UART used:0
                echo "453" > /sys/class/gpio/export
                echo "out" > /sys/class/gpio/gpio453/direction
                echo 0 > /sys/class/gpio/gpio453/value  # pull low for UART usage
            fi

            # cd $MFG_WORK_DIR/mcu_fw_upgrade
        fi

        { echo "$cpu_gpio_uart" > /sys/class/gpio/export; } &> /dev/null
        sleep $CMD_DELAY_TIME

        gpio_export=$( { echo $?; } 2>&1 )
        if (( $gpio_export == 0 )); then    # Export CPU GPIO without fail.
            echo "out" > /sys/class/gpio/gpio${cpu_gpio_uart}/direction
            sleep $CMD_DELAY_TIME
        else
            Error_Message_Handler $ERR_MSG_ASSIGN_GPIO_TO_UART_FAIL
        fi

        ## Switch UART to Target Board's MCU
        if [[ "$_board_type" == "mb" ]]; then
            echo "1" > /sys/class/gpio/gpio${cpu_gpio_uart}/value
        elif [[ "$_board_type" == "fb" ]]; then
            echo "0" > /sys/class/gpio/gpio${cpu_gpio_uart}/value
        fi
        sleep $CMD_DELAY_TIME

        uart_sel=$( cat < /sys/class/gpio/gpio${cpu_gpio_uart}/value )
        sleep $CMD_DELAY_TIME

    elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        ## Switch UART to Target Board's MCU
        if [[ "$_board_type" == "mb" ]]; then
            /sbin/gpio w 104 0x45000201
        elif [[ "$_board_type" == "fb" ]]; then
            /sbin/gpio w 104 0x45000200
        fi
        sleep $CMD_DELAY_TIME

        readGPIO=$( { /sbin/gpio r 104 | cut -c22- ; } 2>&1 )
        sleep $CMD_DELAY_TIME
        uart_sel=${readGPIO: -1:1}
    fi
}

function CPU_UART_Setting_Restore()
{
    if [[ "$SUPPORT_CPU" == "RANGELEY" ]] || [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
        if [[ "$SUPPORT_CPU" == "BDXDE" ]] && [[ "$PROJECT_NAME" != "FHGW" ]]; then
            echo "453" > /sys/class/gpio/export
            echo 1 > /sys/class/gpio/gpio453/value    # resume GPIO-17 value for I2C usage.
            echo "453" > /sys/class/gpio/unexport
        fi
        echo "$cpu_gpio_uart" > /sys/class/gpio/unexport
    elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        readGPIO=$( { /sbin/gpio w 104 0x45000200 ; } 2>&1 )
    fi
}

function Resources_Setting_Restore ()
{
    ## Start Restore setting to default
    if [[ "$_upgrade_method" == "hw" ]]; then
        HW_Hitless_Pin_Control "high"

        sleep 0.01

        if [[ "$PROJECT_NAME" != "ASTON" ]]; then
            # Need to reset both main board and fan board MCU after download by hardware method.
            # Because main board and fan board MCU shared the reset pin.
            # ex: If upgrade main board MCU will also lead to fan board MCU enter bootload mode.
            HW_Reset_Pin_Control "reset"
        fi

        HW_Reset_Pin_Control "restore"

        if [[ "$PROJECT_NAME" != "ASTON" ]]; then
            echo " !! Please reboot DUT later, in order to make MCU FW replace and to make others function working normally !!!"
        fi
    fi

    ## Free the GPIO
    CPU_UART_Setting_Restore
    sleep $CMD_DELAY_TIME

    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        # Control main board MCU 3.3V_Enable to normal mode. (i2cset -y 1 0x73 0x13 0x0)
        Write_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_POWER_CIRCUIT_REG 0x0
    fi

}

function MCU_Enter_Bootloader_Setting()
{
    if (( $uart_sel == $MB_MCU_UART_SEL )); then
        printf "\n[MFG Msg] Choose Main Board MCU to do Firmware Upgrade "

        if [[ "$_upgrade_method" == "sw" ]]; then
            printf "by Software Method\n"
            # Reset main board MCU by software method and enter bootload mode.
            # Write "0xA5" to main board MCU register "0x0" to let main board MCU enter bootload mode. (i2cset -y 0 0x70 0x0 0xA5)
            Write_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_FW_UPGRADE_REG $MCU_FW_UPGRADE_ENABLE
        elif [[ "$_upgrade_method" == "hw" ]]; then
            printf "by Hardware Method\n"
            HW_Hitless_Pin_Control "low"
            HW_Reset_Pin_Control "reset"
        fi

    elif (( $uart_sel == $FB_MCU_UART_SEL )); then
        printf "\n[MFG Msg] Choose Fan Board MCU to do Firmware Upgrade "

        if [[ "$_upgrade_method" == "sw" ]]; then
            printf "by Software Method\n"
            # Write "0xA5" to main board MCU register "0x1" to let fan board MCU enter bootload mode. (i2cset -y 0 0x70 0x1 0xA5)
            Write_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $FB_MCU_FW_UPGRADE_REG $MCU_FW_UPGRADE_ENABLE
        elif [[ "$_upgrade_method" == "hw" ]]; then
            printf "by Hardware Method\n"
            HW_Hitless_Pin_Control "low"
            HW_Reset_Pin_Control "reset"
        fi
    fi

    # Add delay to wait MCU to enter bootload mode.
    sleep $MCU_ENTER_BOOTLOADER_DELAY_TIME
}

function MCU_Bootloader_Check ()
{
    if [[ "$_board_type" == "mb" ]]; then
        result=$( { i2cdetect -y $I2C_BUS_MCU ; } 2>&1 )
        sleep $CMD_DELAY_TIME
        i2c_device=$MB_MCU_ADDR
        i2c_device_num=${i2c_device##*x}
        if [[ "$result" == "$i2c_device_num" ]]; then    # still can see 0x70 exist means not into bootloader yet
            into_bootloader_status="no"
        else
            into_bootloader_status="yes"
            echo " Had into bootloader mode"
        fi
    else # fb
        sleep $MCU_MB_POLLING_FB_DELAY_TIME    # delay 2s to wait MB polling FB
        i2c_result=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_ALERT_REG ; } 2>&1 )
        if (( $(( $i2c_result & $MB_MCU_ALERT_FB_NOT_EXIST_BIT )) == 0x1 )); then
            into_bootloader_status="yes"
        else
            into_bootloader_status="no"
        fi
    fi
}

function MCU_Firmware_Upgrade()
{
    _board_type=$1
    _file_name=$2
    _upgrade_method=$3

    CPU_UART_Setting $_board_type

    if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        # Because Porsche Main Board MCU has power sequence,
        # control 3.3V_Enable to MCU program mode.

        # Control main board MCU 3.3V_Enable to program mode. (i2cset -y 0 0x75 0x13 0x1)
        Write_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_1 $CPLD_B_ADDR $CPLD_B_POWER_CIRCUIT_REG 0x1
    fi

    MCU_Enter_Bootloader_Setting

    ## Check go into bootloader or not, if not then retry once.
    if (( $uart_sel == $MB_MCU_UART_SEL )); then
        MCU_Bootloader_Check $_board_type
        if [[ "$into_bootloader_status" == "no" ]]; then
            echo " # debug : $MB_MCU_ADDR exist = out bootloader mode ... retry ..."
            ## re-request go into bootloader
            MCU_Enter_Bootloader_Setting
            MCU_Bootloader_Check $_board_type
            if [[ "$into_bootloader_status" == "no" ]]; then
                echo " # debug : $MB_MCU_ADDR exist = still out bootloader mode .. will exist upgrade flow now !"
                Resources_Setting_Restore
                exit 1
            fi
        fi
    elif (( $uart_sel == $FB_MCU_UART_SEL )); then
        if [[ "$_upgrade_method" == "sw" ]]; then    # due to HW method will cause both MB/FB MCU into bootloader mode, and then MB MCU can't be access in that time.
            MCU_Bootloader_Check $_board_type
            if [[ "$into_bootloader_status" == "yes" ]]; then
                echo " Had into bootloader mode"
            else
                MCU_Enter_Bootloader_Setting    # re-setting into bootloader again
                MCU_Bootloader_Check $_board_type
                if [[ "$into_bootloader_status" == "yes" ]]; then
                    echo " Retry OK ! Had into bootloader mode"
                else
                    echo " still out bootloader mode ... will exit upgrade flow now !"
                    Resources_Setting_Restore
                    exit 1
                fi
            fi
        fi
    fi

    ## MCU Firmware Upgrade
    printf "[MFG Msg] Please wait MCU image upgrade done, and do NOT shut down the machine.\n\n"
    python $MFG_WORK_DIR/mcu_fw_upgrade/efm8load.py -p "$MCU_UPGRADE_TTY_PORT" "$_file_name"
    sleep $MCU_UPGRADE_DELAY_TIME

    if [[ "$_board_type" == "mb" ]]; then
        printf "\n[MFG Msg] Upgrade Main Board MCU with \"$_file_name\" Done\n\n"
    elif [[ "$_board_type" == "fb" ]]; then
        printf "\n[MFG Msg] Upgrade Fan board MCU with \"$_file_name\" Done\n\n"
    fi

    Resources_Setting_Restore
}

function Upgrade_Through_HW_Method()
{
    if [[ "$PROJECT_NAME" == "FHGW" ]]; then
        I2C_Device_Detect $I2C_BUS_MUX_B_CHANNEL_1 $CPLD_B_ADDR
    else
        i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
        usleep $I2C_ACTION_DELAY

        I2C_Device_Detect $I2C_BUS $CPLD_A_ADDR
    fi

    if (( $device_exist_check == $SUCCESS )); then
        MCU_Firmware_Upgrade $board_type $file_name "hw"
    else
        Error_Message_Handler $ERR_MSG_DEVICE_NOT_DETECT "cpld"
    fi
}

function Denverton_NPU_MCU_Upgrade()
{
    file_name=$1

    EXP_MCU_AP_SIZE=15360
    EXP_MCU_TMP_HEX_LINE=3840
    EXP_MCU_TMP_HEX_SIZE=15360
    EXP_MCU_MAGIC="0xaa 0xbb 0x08 0x05"

    #Step 1: Check input MCU firmware binary size.
    REAL_MCU_SIZE=`ls -al $file_name | awk '{print $5}'`
    if [ "$REAL_MCU_SIZE" != "$EXP_MCU_AP_SIZE" ]; then
        echo "Incorrect input MCU binary file size, exit..."
        exit 1
    fi
    #Step 2: Read binary and transfer to hex.
    hexdump -v -e '4/1 "0x%02x " "\n"' $file_name > tmp

    #Step 3: Check hex file line and size.
    MCU_TMP_HEX_LINE=`cat tmp | wc | awk '{print $1}'`
    MCU_TMP_HEX_SIZE=`cat tmp | wc | awk '{print $2}'`
    if [ "$MCU_TMP_HEX_LINE" != "$EXP_MCU_TMP_HEX_LINE" ] || [ "$MCU_TMP_HEX_SIZE" != "$EXP_MCU_TMP_HEX_SIZE" ]; then
        echo "Incorrect transfer MCU hex file size, exit..."
        exit 1
    fi

    #Step 4: Check magic number.
    MCU_MAGIC=`cat tmp | tail -n 2 | head -n 1`
    if [ "$MCU_MAGIC" != "$EXP_MCU_MAGIC" ]; then
        echo "Incorrect MCU magic, exit..."
        exit 1
    fi

    #Step 5: REG41_READY_FOR_UPGRADE
    RES=`Read_I2C_Device_Node $I2C_BUS_ARBITER_AND_AFTER $NPU_CONTROL_CHIP_ADDR 0x41`
    sleep 1s

    #Step 6: Start to upgrade...
    echo "Start upgrading..."
    while read line
    do
        echo -n "."
        CMD="i2cset -f -y $I2C_BUS_ARBITER_AND_AFTER $NPU_CONTROL_CHIP_ADDR 0x42 $line i"
        RES=`$CMD`
    done < tmp
    echo "Done."

    #Step 7: REG43_FILE_TRANSFER_OK
    RES=`Read_I2C_Device_Node $I2C_BUS_ARBITER_AND_AFTER $NPU_CONTROL_CHIP_ADDR 0x43`
    sleep 1s

    #Step 8:
    if [[ ! -z "$2" ]] && [[ "$2" == "test" ]]; then
        echo "Please reset DUT to make FW replace old."
    else
        echo "Reset MCU..."
        sleep 5s
        RES=`Read_I2C_Device_Node $I2C_BUS_ARBITER_AND_AFTER $NPU_CONTROL_CHIP_ADDR 0x43`
    fi
}

function Help_Message()
{
    printf "\n[MFG] MCU Firmware Upgrade Help Message\n"
    printf "   Command         : ./mfg_sources/mcu_fw_upgrade.sh [device] [file name] [method]\n"
    printf "   Command Example : ./mfg_sources/mcu_fw_upgrade.sh mb ImageName.efm8 sw\n"
    printf "   Parameter Description :\n"
    printf "   [device]    {mb/fb/npu} : Type mb/fb/npu to do main/fan/npu board MCU firmware upgrade.\n"
    printf "   [file name] {ImageName} : Type image name under \"mcu_fw_upgrade\" folder directly.\n"
    printf "                             Please do NOT change the image name.\n"
    printf "   [method]    {sw/hw}     : Select sw/hw to upgrade MCU firmware by software/hardware method.\n"
    printf "\n"

    printf "   P.S. Default use software method to upgrade image.\n"
    printf "\n"

    exit 1
}

function Error_Message_Handler()
{
    error_id=$1
    sel=$2

    printf "\n[MFG Error Msg] MCU Firmware Upgrade Error !\n"

    case $error_id in
        $ERR_MSG_SEL_BOARD_FAIL)
            printf "[Error] Input board type selection NOT correct\n"
            printf "        Make sure to type mb/fb/npu to do Main/FanBoard MCU firmware upgrade.\n"
            ;;
        $ERR_MSG_IN_FILE_EMPTY)
            printf "[Error] Input file parameter is EMPTY.\n"
            ;;
        $ERR_MSG_IN_FILE_NOT_EXIST)
            printf "[Error] Input file NOT exist.\n"
            ;;
        $ERR_MSG_IN_FILE_CHOOSE_WRONG)
            printf "[Error] Input file choose NOT correct.\n"
            if [[ "$sel" == "mb" ]]; then
                printf "Input parameter is \"mb(main board)\", "
                printf "  but input firmware is NOT for \"main board\" MCU.\n"
            elif [[ "$sel" == "fb" ]]; then
                printf "Input parameter is \"fb(fan board)\", "
                printf "  but input firmware is NOT for \"fan board\" MCU.\n"
            elif [[ "$sel" == "npu" ]]; then
                printf "Input firmware is NOT for \"NPU board\" MCU.\n"
            elif [[ "$sel" == "unsupport" ]]; then
                printf "Input firmware is NOT support for this board version.\n"
            fi
            ;;
        $ERR_MSG_CHECKSUM_FAIL)
            printf "[Error] Input file checksum is NOT correct.\n"
            ;;
        $ERR_MSG_DEVICE_NOT_DETECT)
            if [[ "$sel" == "mcu" ]]; then
                printf "[Error] Device Main Board MCU($MB_MCU_ADDR) NOT Detect on I2C Bus $I2C_BUS_MCU !\n"
                return
            elif [[ "$sel" == "cpld" ]]; then
                printf "[Error] Device CPLD($cpld_addr) NOT Detect on I2C Bus $I2C_BUS_MUX_B_CHANNEL_0 !\n"
            elif [[ "$sel" == "other" ]]; then
                printf "[Error] Device NOT Detect on I2C Bus $I2C_BUS_MCU !\n"
            fi
            ;;
        $ERR_MSG_ASSIGN_GPIO_TO_UART_FAIL)
            printf "[Error] CPU GPIO do NOT assign correctly.\n"
            ;;
        *)  ;;
    esac

    printf "\n"
    exit 1
}

function Parsing_FileName()
{
    _board_type=$1
    _file_name=$2

    if [[ "$_file_name" == *"/"* ]]; then
        sub_file_name=$( ls $_file_name | rev | cut -d '/' -f 1 | rev )
        _file_name=$sub_file_name
    fi

    printf "\nInput File Name => %s\n" $_file_name

    fNameLen=$(expr length $_file_name)
    #printf "Input File Name Length => %d\n" $fNameLen

    underline_cnt=0
    substr_start=1
    for (( i = 1 ; i <= $fNameLen ; i += 1 ))
    do
        str=$(expr substr $_file_name $i 1)

        # Project_BoardType_Pin_MajorVer_MinorVer   #_Checksum
        # ex: Cadillac_MainBoard_24pin_V1_0     #_ABCD1234

        if [ "$str" == "_" ]; then
            underline_cnt=$(( $underline_cnt + 1 ))
            substr_end=$i

            # In Major Version string pass character 'V'
            if (( $underline_cnt == 4 )); then
                substr_start=$(( $substr_start + 1 ))
            elif (( $underline_cnt == 5 )); then
                checksum_start=$(( $i + 1 ))
                #printf "CheckSum Start Position => %d\n" $checksum_start
            fi
            #printf "substr_start => %d, substr_end => %d\n" $substr_start $substr_end

            fNameSubStr=$(expr substr $_file_name $substr_start $(( $substr_end - $substr_start )))

            case $underline_cnt in
                1)
                    printf "Project Name => %s\n" $fNameSubStr
                    ;;
                2)
                    printf "Board Type   => %s\n" $fNameSubStr
                    image_board_type=$fNameSubStr
                    ;;
                3)
                    printf "Pin Type     => %s\n" $fNameSubStr
                    ;;
                4)
                    #printf "MCU Firmware Major Version => %s\n" $fNameSubStr
                    major_ver=$fNameSubStr
                    ;;
                5)
                    #printf "MCU Firmware Minor Version => %s\n" $fNameSubStr
                    minor_ver=$fNameSubStr
                    ;;
                *) ;;
            esac

            if (( $underline_cnt == 5 )); then
                printf "MCU Firmware Version => %s.%s\n" $major_ver $minor_ver
                break
            fi

            substr_start=$(( $substr_end + 1 ))
        fi
    done

    if [[ "$image_board_type" == "MainBoard" ]] || [[ "$image_board_type" == "mainboard" ]] ; then
        if [[ "$_board_type" == "mb" ]]; then
            board_type_check=$SUCCESS

            ## 20200325 Jenny add special case for Gemini
            ##     MB v1.00 can't install FW v0.7 or newer ; MB v2.00 can't install FW v0.6 or older.
            if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
                data_result=$( { Read_I2C_Device_Node $I2C_BUS_MUX_B_CHANNEL_0 $CPLD_A_ADDR $CPLD_VER_REG ; } 2>&1 )
                mb_hw_ver=$(($data_result >> 5))
                if (( $mb_hw_ver == 1 && $minor_ver >=4 )) || (( $mb_hw_ver == 2 && $minor_ver <=3 )); then
                    Error_Message_Handler $ERR_MSG_IN_FILE_CHOOSE_WRONG "unsupport"
                fi
            fi
        else
            board_type_check=$FAIL
        fi
    elif [[ "$image_board_type" == "FanBoard" ]] || [[ "$image_board_type" == "fanboard" ]]; then
        if [[ "$_board_type" == "fb" ]]; then
            board_type_check=$SUCCESS
        else
            board_type_check=$FAIL
        fi
    else
        printf "[MFG Error Msg] Cannot Check Board Type by Image Name\n"
        exit 1
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

function Resend_Board_ID_To_FanBoard()
{
    ## Check Main Board MCU(0x70) on I2C bus or not.
    I2C_Device_Detect $I2C_BUS_MCU $MB_MCU_ADDR

    ## If main board MCU alert mode set to "Keep(read on clear), need read-out to clear."
    ## Because main board MCU will check this register before re-send board-id.
    tempVal=$( { Read_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $MB_MCU_I2C_BUS_ALERT_REG ; } 2>&1 )

    if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        Write_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $FB_MCU_BOARD_ID_SET_REG 0x0
    elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
        Write_I2C_Device_Node $I2C_BUS_MCU $MB_MCU_ADDR $FB_MCU_BOARD_ID_SET_REG 0x3
    fi
}

##### Main Function #####
board_type=$1
file_name=$2
upgrade_method_sel=$3

cd $MFG_WORK_DIR/mcu_fw_upgrade
sleep $CMD_DELAY_TIME

if [ -z "$board_type" ] || [[ "$board_type" == "?" ]] ||
   [[ "$board_type" == "-h" ]] || [[ "$board_type" == "--help" ]]; then
    Help_Message
elif [[ "$board_type" != "mb" ]] && [[ "$board_type" != "fb" ]] && [[ "$board_type" != "npu" ]]; then
    Error_Message_Handler $ERR_MSG_SEL_BOARD_FAIL
elif [ -z "$MFG_WORK_DIR/mcu_fw_upgrade/$file_name" ] && [ -z "$file_name" ]; then
    Error_Message_Handler $ERR_MSG_IN_FILE_EMPTY
elif [ ! -e "$MFG_WORK_DIR/mcu_fw_upgrade/$file_name" ] && [ ! -e "$file_name" ]; then
    Error_Message_Handler $ERR_MSG_IN_FILE_NOT_EXIST
else
    if [[ "$board_type" == "npu" ]] && [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        Denverton_NPU_MCU_Upgrade $file_name
        exit 1
    fi

    Parsing_FileName $board_type $file_name

    if (( $board_type_check == $FAIL )); then
        Error_Message_Handler $ERR_MSG_IN_FILE_CHOOSE_WRONG $board_type
    else
        if [ -z "$upgrade_method_sel" ]; then
            upgrade_method_sel="sw"
        fi

        #Compare_Checksum $file_name

        #if [[ $checksum_check == "$SUCCESS" ]]; then
            Mutex_Check_And_Create
            if (( $FLAG_USE_IPMI == "$TRUE" )); then
                swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
            fi

            if [[ "$upgrade_method_sel" == "sw" ]]; then
                ## Check Main Board MCU(0x70) on I2C bus or not.
                I2C_Device_Detect $I2C_BUS_MCU $MB_MCU_ADDR

                ## If Main Board MCU exactly exist on I2C bus
                if (( $device_exist_check == $SUCCESS )); then
                    MCU_Firmware_Upgrade $board_type $file_name "sw"
                else
                    ## MB MCU NOT exist on I2C bus, use hardware method to upgade MCU firmware !!!
                    Error_Message_Handler $ERR_MSG_DEVICE_NOT_DETECT "mcu"
                    Upgrade_Through_HW_Method
                fi
            elif [[ "$upgrade_method_sel" == "hw" ]]; then
                Upgrade_Through_HW_Method
            fi

            if [[ "$board_type" == "fb" ]]; then
                Resend_Board_ID_To_FanBoard
            fi

            Mutex_Clean
            if (( $FLAG_USE_IPMI == "$TRUE" )); then
                swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
            fi
        #else
        #   Error_Message_Handler $ERR_MSG_CHECKSUM_FAIL
        #fi
    fi
fi

