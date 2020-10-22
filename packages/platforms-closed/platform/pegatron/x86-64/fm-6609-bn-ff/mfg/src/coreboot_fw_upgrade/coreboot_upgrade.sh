#! /bin/bash

########################################################################
# This script is to update coreboot image (SPI firmware) in BIOS region.
########################################################################

source /home/root/mfg/mfg_sources/platform_detect.sh

BDX_BIOS_REGION_STARTADDR=0xe00000
BDX_BIOS_REGION_OFFSET=0x200000
COREBOOT_SIZE=2097152         # coreboot.rom = 2MB

function Read_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register $i2c_data
        usleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE ; } 2>&1 )
        ipmi_value_toHex=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 2)))" ; } 2>&1 )    # orig value format is " XX" , so just get XX then transform as 0xXX format.
        echo $ipmi_value_toHex    # this line is to make return with value 0xXX
        return
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
    usleep 100000
}

function Mutex_Clean()
{
    rm $I2C_MUTEX_NODE
    sync
    usleep 100000
}

if [[ "$SUPPORT_CPU" != "BDXDE" ]]; then
    echo " Sorry, this script only supported on Intel BDX-DE ."
    exit 1
else
    if (( $# < 1 )); then
        echo " Need to input 'action' [upgrade/erase] , and new FW (size is 2MB) 'location' if action choose upgrade."
    else
        Mutex_Check_And_Create
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
        fi

        sel_ori=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR $BDX_CONTROL_CHIP_SEL_REG ; } 2>&1 )

        Mutex_Clean
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
        fi

        if (( ( $sel_ori & 0x1 ) == $BDX_CONTROL_CHIP_SEL_DEFAULT ));then
            flag_current="Default"
        else
            flag_current="Golden"
            echo " # Not support Golden SPI upgrade for safety."
            exit 1
        fi

        if [[ "$1" == "erase" ]]; then
            echo " Will start to erase partition"
            mtd_debug erase /dev/mtd0 $BDX_BIOS_REGION_STARTADDR $BDX_BIOS_REGION_OFFSET
            echo " # Erase partition DONE."
        else
            NEW_FILE=$2
            fileSize=$( { ls -al $NEW_FILE | awk '{print $5}' ; } 2>&1 )
            if [[ "$fileSize" != "$COREBOOT_SIZE" ]]; then
                echo " Input coreboot.rom file size need match 2MB !!!"
                exit 1
            else
                ## clean BIOS region of SPI first.
                echo " Clean old coreboot file first..."
                mtd_debug erase /dev/mtd0 $BDX_BIOS_REGION_STARTADDR $BDX_BIOS_REGION_OFFSET

                sleep 3

                ## write new BIOS FW
                echo " Start update coreboot.rom ..."
                mtd_debug write /dev/mtd0 $BDX_BIOS_REGION_STARTADDR $BDX_BIOS_REGION_OFFSET $NEW_FILE
                sleep 3
                echo " # Upgrade $flag_current SPI BIOS firmware DONE."
            fi
        fi
    fi
fi
