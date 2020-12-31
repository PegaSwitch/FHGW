#! /bin/bash
#########################################################################################################
# This is for ONIE SYSEERPOM pre-definition to MB EEPROM.
# Below can setting individually:
#   ProductName (0x21), SerialNumber (0x23), BaseMACAddr (0x24), ManufactureDate (0x25), MACsNum (0x2a).
# Below are N/A:
#   PartNumber (0x22), ServiceTag (0x2f).
# Note :: ONIE_VERSION value will be auto updated while ONIE install, so value will unmatch defined here.
#########################################################################################################

source /home/root/mfg/mfg_sources/platform_detect.sh

#PART_NUMBER=UNDIFINED
#SERIAL_NUMBER
#MAC_BASE_ADDRESS
#MANUFACTURE_DATE
DEVICE_VERSION="0"
LABEL_REVISION="0"
COUNTRY_CODE="TW"
VENDOR="Pegatron"
DELAY_GAP=100000
CMD_ACTION_DELAY=100000

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

function Check_And_Set ()
{
    eeprom_offset=$1
    eeprom_value=$2

    check=$( { onie_syseeprom -g $eeprom_offset ; } 2>&1 )
    usleep $CMD_ACTION_DELAY
    if [[ "$check" == *"TLV code not present"* ]]; then
        onie_syseeprom -s $eeprom_offset="$eeprom_value"
        usleep $CMD_ACTION_DELAY
    elif [[ "$eeprom_offset" == "0x2e" ]] && [[ "$check" != "$DIAG_VERSION" ]]; then    ## This is for auto-check DIAG version.
        onie_syseeprom -s $eeprom_offset="$DIAG_VERSION"
        usleep $CMD_ACTION_DELAY
    elif [[ "$eeprom_offset" == "0x21" ]] && [[ "$check" != "$PRODUCT_NAME" ]]; then    ## This is for auto-check ONIE ID.
        onie_syseeprom -s $eeprom_offset="$PRODUCT_NAME"
        usleep $CMD_ACTION_DELAY
    elif [[ "$eeprom_offset" == "0x26" ]] && [[ "$check" != "$DEVICE_VERSION" ]]; then    ## This is for auto-check MB version.
        onie_syseeprom -s $eeprom_offset="$DEVICE_VERSION"
        usleep $CMD_ACTION_DELAY
    else
        echo " $eeprom_offset value has been set to EEPROM" > /dev/null
    fi
}

if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    ## check BMC exist or not
    if [[ ! -z "/dev/ipmi0" ]] && [[ "$gpio_bmc_present" == 0 ]];then
        FLAG_BMC_EXIST=1
    else
        FLAG_BMC_EXIST=0
    fi
fi

if [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
    DIAG_VERSION="DIAG_0.2.1"                    # version base on 0.0.19 (common-rootfs)
    ONIE_VERSION="devel-201907171413-dirty"      # by 20190717 Wolf gave customized diag-log partition.
    PLATFORM_NAME="x86_64-flnet_s8930_54n-r0"    #"x86_64-pegatron_fn_6254_dn_f-r0"
    MANUFACTURER="Flnet"
    MAC_NUMBERS="73"
elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
    PRODUCT_NAME="FB-6032-BN-F"
    DIAG_VERSION="DIAG_1.5.1"
    ONIE_VERSION="common-bdx-devel-20190624-dirty"
    PLATFORM_NAME="x86_64-pegatron_fb_6032_bn_f-r0"
    MANUFACTURER="Pegatron"
    MAC_NUMBERS="129"
elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    if (( $FLAG_BMC_EXIST == 0 )); then
        PRODUCT_NAME="FM-6256-BN-F"
        PLATFORM_NAME="x86_64-pegatron_fm_6256_bn_f-r0"
    else
        PRODUCT_NAME="FM-6256-BA-F"
        PLATFORM_NAME="x86_64-pegatron_fm_6256_ba_f-r0"
    fi
    DIAG_VERSION="MFG_0.1.3"
    ONIE_VERSION="pegatron-common_bde-2020.05-7"
    MANUFACTURER="Pegatron"
    MAC_NUMBERS="83"        # 48+8*4+1+2=83
fi

if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

## MB Board version, by detect real pin defined in CPLD(A)
Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
data_result=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR $CPLD_VER_REG ; } 2>&1 )
hw_ver=$(($data_result >> 5))
DEVICE_VERSION=$hw_ver

Check_And_Set 0x21 "$PRODUCT_NAME"
usleep $DELAY_GAP
#Check_And_Set 0x22 "$PART_NUMBER"
#usleep $DELAY_GAP
#Check_And_Set 0x23 "$SERIAL_NUMBER"
#usleep $DELAY_GAP
#Check_And_Set 0x24 "$MAC_BASE_ADDRESS"
#usleep $DELAY_GAP
#Check_And_Set 0x25 "$MANUFACTURE_DATE"
#usleep $DELAY_GAP
Check_And_Set 0x26 "$DEVICE_VERSION"
usleep $DELAY_GAP
Check_And_Set 0x27 "$LABEL_REVISION"
usleep $DELAY_GAP
Check_And_Set 0x28 "$PLATFORM_NAME"
usleep $DELAY_GAP
Check_And_Set 0x29 "$ONIE_VERSION"
usleep $DELAY_GAP
Check_And_Set 0x2a "$MAC_NUMBERS"
usleep $DELAY_GAP
Check_And_Set 0x2b "$MANUFACTURER"
usleep $DELAY_GAP
Check_And_Set 0x2c "$COUNTRY_CODE"
usleep $DELAY_GAP
Check_And_Set 0x2d "$VENDOR"
usleep $DELAY_GAP
Check_And_Set 0x2e "$DIAG_VERSION"
usleep $DELAY_GAP

if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi
