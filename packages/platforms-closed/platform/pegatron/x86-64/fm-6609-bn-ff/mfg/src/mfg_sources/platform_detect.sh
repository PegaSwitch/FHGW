#! /bin/bash

####################################################
## DO NOT MODIFY BELOW COMMON CONSTANT/VARIABLE !!!
## For each project, please add your own function,
##    with all big-endian variables.
####################################################

### Belows Global Variables are Common Defined in each Projects.
## CPU related
CPU_RANGELEY=C2538
CPU_DENVERTON=C3538
CPU_BDXDE=(1507 1517 1527)    ## D-15X7
NPU_CONTROL_CHIP_ADDR=0x18    #BDXDE-CPLD ; DNV-MCU
NPU_TEMPER_SENSOR_ADDR=0x4A
## Denverton SPI chip select by MCU.
DNV_CONTROL_CHIP_SEL_REG=0x70
DNV_CONTROL_CHIP_SEL_DEFAULT=0x1
DNV_CONTROL_CHIP_SEL_GOLDEN=0x0
DNV_GPIO_EXPANDER_ADDR=0x23
## BDXDE SPI chip select by CPLD.
BDX_CONTROL_CHIP_SEL_REG=0x4
BDX_CONTROL_CHIP_SEL_DEFAULT=0x1
BDX_CONTROL_CHIP_SEL_GOLDEN=0x0
BDX_MISC_CNTL_REG=0x4
BDX_REPOWER_CYCLE_MASK=0x02   # CPLD register 4 [1]    

SUPPORT_CPU="no"
GPIO_MUTEX_NODE="/tmp/gpio-node-exist"

## BMC related
BMC_NET_FUNCTION=0x3C
BMC_I2C_GET=0xE0
BMC_I2C_SET=0xE1
BMC_I2C_ACCESS_DATALEN_ONE=0x1
BMC_I2C_ACCESS_DATALEN_TWO=0x2
BMC_SENSOR_MONITOR_REG=0xED
BMC_SENSOR_DISABLE=0x0
BMC_SENSOR_ENABLE=0x1

## I2C related
I2C_MUX_A=0x72
I2C_MUX_B=0x73
I2C_MUX_REG=0x0
I2C_ACTION_DELAY=100000
I2C_MUTEX_NODE="/tmp/i2c-bus-mutex"

## I2C Arbiter
I2C_ARBITER_ADDR=0x71
I2C_ARBITER_CTRL_REG=0x1
I2C_ARBITER_LOCK=1
I2C_ARBITER_RELEASE=0

## CPLD related, CPLD-D is on BDX NPU.
CPLD_A_ADDR=0x74
CPLD_B_ADDR=0x75
CPLD_C_ADDR=0x76
CPLD_VER_REG=0x0
CPLD_D_BMCR1_REG=0x0B
CPLD_D_LEDCR1_REG=0x6       ## for BDX-DE CPLD-D ; LED Control Register#1
CPLD_D_LEDCR2_REG=0x7       ## for BDX-DE CPLD-D ; LED Control Register#2
CPLD_D_LEDCR1_LOC_BLUE_MASK=0x00    ## LOC bit[1:0] blue on  (Keep SYS[7:5] and PWR[4:2] setting by MB CPLD)
CPLD_D_LEDCR1_LOC_OFF_MASK=0x01     ## LOC bit[1:0] blue off (Keep SYS[7:5] and PWR[4:2] setting by MB CPLD)
CPLD_D_LEDCR2_BMC_GREEN_MASK=0x00   ## BMC bit[5:3] green on (Keep FAN bit[2:0] setting by MB CPLD)
CPLD_D_LEDCR2_BMC_RED_MASK=0x08     ## BMC bit[5:3] red on   (Keep FAN bit[2:0] setting by MB CPLD)
CPLD_D_LEDCR2_BMC_OFF_MASK=0x10     ## BMC bit[5:3] green & red off (Keep FAN bit[2:0] setting by MB CPLD)
CPLD_D_LEDCR2_BMC_BLINK_MASK=0x20   ## BMC bit[5:3] green blink (Keep FAN bit[2:0] setting by MB CPLD)

## PSU related
I2C_MUX_CHANNEL_PSU_A=$I2C_MUX_A_CHANNEL_0
I2C_MUX_CHANNEL_PSU_B=$I2C_MUX_A_CHANNEL_1
PSU_A_ADDR=0x58
PSU_B_ADDR=0x59

## MCU related
MCU_AMOUNT=2
MB_MCU_ADDR=0x70
MB_MCU_PROJECT_ID_REG=0x2
MB_MCU_HW_VERSION_REG=0x2
MB_MCU_SW_VERSION_REG=0x4
FB_MCU_HW_VERSION_REG=0x3
FB_MCU_SW_VERSION_REG=0x5
MB_MCU_TEMPER_SENSOR_PCB_REG=0x70
MB_MCU_TEMPER_SENSOR_MAC_REG=0x71
MB_MCU_TEMPER_SENSOR_FB_REG=0x72
MB_MCU_ADC_MONITOR_BASE_REG=0x60    # 0x60~0x6a, by each project different !
MB_MCU_FAN_PWM_REG=0x10
MB_MCU_SMARTFAN_ENABLE_BASE_REG=0x11
MB_MCU_SMARTFAN_TUNE_REG=0x12
MB_MCU_FAN_INNER_RPM_BASE_REG=0x20
MB_MCU_FAN_OUTER_RPM_BASE_REG=0x30
MB_MCU_FAN_STATUS_BASE_REG=0x40
MB_MCU_FAN_ALERT_REG=0x53           # 0x53~0x57
MB_MCU_FAN_ALERT_CONT_REG=0x5a      # 0x5A ( is for 6-fans )
MB_MCU_FAN_ALERT_MODE_REG=0x59
MB_MCU_I2C_BUS_ALERT_REG=0x58
## For fan_XXXX_by_cpu.sh
#BY_CPU_FB_MCU_SW_VERSION_REG=0xa0
#BY_CPU_FB_MCU_HW_VERSION_REG=0xa2
BY_CPU_FB_MCU_ADDR=0x47
BY_CPU_FB_MCU_PWM_READ_REG=0x20
BY_CPU_FB_MCU_PWM_WRITE_REG=0x21
BY_CPU_FB_MCU_INNER_RPM_BASE_REG=0x40    ## fanboard inner rpm (0x40 + 4x)
BY_CPU_FB_MCU_OUTER_RPM_BASE_REG=0x42    ## fanboard inner rpm (0x42 + 4x)
BY_CPU_FB_MCU_STATUS_READ_BASE_REG=0x60       ## fanboard read status  (0x60 + 4x)
BY_CPU_FB_MCU_STATUS_WRITE_BASE_REG=0x61      ## fanboard write status (0x61 + 4x)
## bit mask
FB_MCU_PRESENT_ALERT_MASK=0x80
BY_CPU_FB_MCU_ENABLE_MASK=0x40
BY_CPU_FB_MCU_LED_AUTO_MASK=0x20
BY_CPU_FB_MCU_LED_GREEN_MASK=0x10
BY_CPU_FB_MCU_LED_AMBER_MASK=0x08
BY_CPU_FB_MCU_ALERT_MASK=0x04
BY_CPU_FB_MCU_AIRFLOW_MASK=0x02
## Fan Alert Function Mask, used in fan_monitor_by_cpu.sh & diag_fan_test.sh
FB_MCU_NOT_CONNECT_MASK=0x80
FB_MCU_INNER_RPM_ZERO_MASK=0x40
FB_MCU_INNER_RPM_UNDER_MASK=0x20
FB_MCU_INNER_RPM_OVER_MASK=0x10
FB_MCU_OUTER_RPM_ZERO_MASK=0x08
FB_MCU_OUTER_RPM_UNDER_MASK=0x04
FB_MCU_OUTER_RPM_OVER_MASK=0x02
FB_MCU_WRONG_AIRFLOW_MASK=0x01
FB_MCU_I2C_BUS_ALERT_MASK=0x1
## rpm tolerance
#BY_CPU_FB_MCU_MID_PWM_READ_REG=0x80
#BY_CPU_FB_MCU_MID_PWM_WRITE_REG=0x81
#BY_CPU_FB_MCU_LOW_TOL_READ_REG=0x84
#BY_CPU_FB_MCU_LOW_TOL_WRITE_REG=0x85
#BY_CPU_FB_MCU_HIGH_TOL_READ_REG=0x88
#BY_CPU_FB_MCU_HIGH_TOL_WRITE_REG=0x89

## Multiphase Controller related
PMBUS_NPU_63_ADDR=0x63
PMBUS_NPU_64_ADDR=0x64
PMBUS_NVM_CHECKSUM_REG=0x9E
PMBUS_INTERFACE_REG=0xd2
PMBUS_INTERFACE_PMBUS=0x1
PMBUS_INTERFACE_SVID=0x2
PMBUS_CHANNEL_REG=0x0
PMBUS_CHANNEL_A=0x0
PMBUS_CHANNEL_B=0x1
MPC_TPS536XX_PAGE_REG=0x0
MPC_TPS536XX_OPERATION_REG=0x1
MPC_TPS536XX_PHASE_REG=0x4
MPC_TPS536XX_VOUT_COMMAND_REG=0x21
MPC_TPS536XX_VOUT_MAX_REG=0x24
MPC_TPS536XX_VOUT_MIN_REG=0x2B
MPC_TPS536XX_READ_VIN_REG=0x88
MPC_TPS536XX_READ_TEMPERATURE_1_REG=0x8D
MPC_TPS536XX_READ_TEMPERATURE_2_REG=0x8E
MPC_TPS536XX_READ_I_IN_REG=0x89
MPC_TPS536XX_READ_V_OUT_REG=0x8B
MPC_TPS536XX_READ_I_OUT_REG=0x8C
MPC_TPS536XX_READ_P_OUT_REG=0x96
MPC_TPS536XX_READ_P_IN_REG=0x97

## System LED Control
## 000x_xxxx  :  Green On
## 001x_xxxx  :  Amber On
## 010x_xxxx  :  Green & Amber Off
## 011x_xxxx  :  Green Blinking
## 100x_xxxx  :  Amber Blinking
## System LED Mask
DIAG_SYS_LED_GREEN_ON_MASK=0x00
DIAG_SYS_LED_AMBER_ON_MASK=0x20
DIAG_SYS_LED_GREEN_BLINK_MASK=0x60
DIAG_SYS_LED_AMBER_BLINK_MASK=0x80

## Diag-test for PT-4C mode usage
DIAG_STORAGE_TEST_CHECK_BUFFER_TIME="2"    # minute
DIAG_TRAFFIC_TEST_CHECK_BUFFER_TIME="2"    # minute ; Marvell chipset defined in their SDK.

## QSFP-DD Module Registers
QSFPDD_PAGE_REG=0x7F
QSFPDD_TEMP_BOTTOM_CASE_MSB_REG=0xC
QSFPDD_TEMP_BOTTOM_CASE_LSB_REG=0xD
QSFPDD_TEMP_TOP_CASE_MSB_REG=0xE
QSFPDD_TEMP_TOP_CASE_LSB_REG=0xF
QSFPDD_VOLTAGE_VCC_RX_MSB_REG=0x10
QSFPDD_VOLTAGE_VCC_RX_LSB_REG=0x11
QSFPDD_VOLTAGE_VCC_TX_MSB_REG=0x12
QSFPDD_VOLTAGE_VCC_TX_LSB_REG=0x13
QSFPDD_VOLTAGE_VCC_MSB_REG=0x16
QSFPDD_VOLTAGE_VCC_LSB_REG=0x17
QSFPDD_POWER_SET_REG=0xC8

## Traffic Test Mode Define
TRAFFIC_TEST_MODE_EDVT_INTERNAL=1   ## Internal Traffic Test (send packets by DUT CPU)
TRAFFIC_TEST_MODE_EDVT_EXTERNAL=2   ## External Traffic Test (send packets with IXIA)
TRAFFIC_TEST_MODE_PT_PRETEST=3
TRAFFIC_TEST_MODE_PT_BURNIN=4

## Others function related
MODULE_EEPROM_ADDR=0x50
MB_EEPROM_ADDR=0x54
MB_EEPROM_SIZE=256
TEMPER_SENSOR_REG=0x0

## Constant Variable Define
FALSE=0
TRUE=1
SUCCESS=1
FAIL=0
PASS=1

## Working Directory Define
MFG_WORK_DIR="/home/root/mfg"
MFG_SOURCE_DIR=$MFG_WORK_DIR/mfg_sources
I2C_TOOLS_PATH="$MFG_WORK_DIR/i2c-tools"
BACKUP_ORIG_I2C_TOOLS="$I2C_TOOLS_PATH/i2c_origin/"

## storage related.
EMMC_LABEL="usb-Generic-_Multiple_Reader"
SSD_LABEL="ata-"
STORAGE_TEST_INPUT_FILE="/dev/urandom"
FOLDER_PATH_EMMC="/home/root/eMMC"
FOLDER_PATH_EMMC_TEST_AREA="$FOLDER_PATH_EMMC/rwTest"
FOLDER_PATH_USB="/home/root/USB"
FOLDER_PATH_USB_TEST_AREA="$FOLDER_PATH_USB/rwTest"
FOLDER_PATH_SSD="/home/root/SSD"
FOLDER_PATH_SSD_TEST_AREA="$FOLDER_PATH_SSD/rwTest"

## Log path define
LOG_PATH_HOME="/home/root/testLog"
LOG_PATH_I2C="$LOG_PATH_HOME/I2C"
LOG_PATH_OOB="$LOG_PATH_HOME/OOB"
LOG_PATH_STORAGE="$LOG_PATH_HOME/storage"
LOG_PATH_HWMONITOR="$LOG_PATH_HOME/hw_monitor"
LOG_PATH_MAC="$LOG_PATH_HOME/MAC"
LOG_PATH_FAN="$LOG_PATH_HOME/fan"

LOG_DIAG_TRAFFIC_RESULT_TMP="${LOG_PATH_HOME}/diag_traffic_test_result.tmp"   ## called in Diag_test & diag_traffic_test
LOG_DIAG_COMPONENT_RESULT_TMP="${LOG_PATH_HOME}/diag_storage_test_result.tmp" ## called in Diag_test & diag_component_test
LOG_DIAG_FAN_RESULT_TMP="${LOG_PATH_HOME}/diag_fan_test_result.tmp"           ## called in Diag_test & diag_fan_test
LOG_DIAG_I2C_RESULT_TMP="${LOG_PATH_HOME}/diag_i2c_test_result.tmp"           ## called in Diag_test & i2c_bus_test

LOG_DIAG_VERSION_CHECK="$LOG_PATH_HOME/fw_version_check.log"                  ## called in Diag_test & i2c_bus_test.sh
LOG_DIAG_VERSION_SPI="$LOG_PATH_STORAGE/spi_md5test.log"

DIAG_CONF_FILE_NAME=${MFG_SOURCE_DIR}/diag_test.conf
HW_MONITOR_DONE_NODE="/tmp/hw-monitor-done"

## Rootfs Init define
platform_init_flag="/tmp/platform-init-done"
rootfs_create_ready_flag="/tmp/fs-create-ready"

## ONIE related
ONIE_ACCESS_WAY=1    ## if use onie-syseeprom, set the flag to 1 ; or set to 0
ONIE_PARTITION_DIAG_NAME="PEGATRON-DIAG"    ## need request ONIE team modify to "MFG-DIAG".
ONIE_PARTITION_LOG_NAME="LOG-DIAG"
ONIE_TLVDATA_START_OFFSET=12
ONIE_PRODUCTNAME_TYPECODE=0x21
ONIE_SN_TYPECODE=0x23
ONIE_MAC_TYPECODE=0x24
ONIE_MACNUM_TYPECODE=0x2a

timestamp() {
        date +"%Y-%m-%d %H:%M:%S"
}

function MUX_Channel_Define ()
{
    if [[ "$mux_a" == "PCA9545" ]]; then
        #I2C MUX(A) PCA9545
        I2C_MUX_A_CHANNEL_0=0x1
        I2C_MUX_A_CHANNEL_1=0x2
        I2C_MUX_A_CHANNEL_2=0x4
        I2C_MUX_A_CHANNEL_3=0x8
    else
        #I2C MUX(A) PCA9544
        I2C_MUX_A_CHANNEL_0=0x4
        I2C_MUX_A_CHANNEL_1=0x5
        I2C_MUX_A_CHANNEL_2=0x6
        I2C_MUX_A_CHANNEL_3=0x7
    fi

    if [[ "$mux_b" == "PCA9548" ]]; then
        #I2C MUX(B) PCA9548
        I2C_MUX_B_CHANNEL_0=0x1
        I2C_MUX_B_CHANNEL_1=0x2
        I2C_MUX_B_CHANNEL_2=0x4
        I2C_MUX_B_CHANNEL_3=0x8
        I2C_MUX_B_CHANNEL_4=0x10
        I2C_MUX_B_CHANNEL_5=0x20
        I2C_MUX_B_CHANNEL_6=0x40
        I2C_MUX_B_CHANNEL_7=0x80
    else
        #I2C MUX(B) PCA9544
        I2C_MUX_B_CHANNEL_0=0x4
        I2C_MUX_B_CHANNEL_1=0x5
        I2C_MUX_B_CHANNEL_2=0x6
        I2C_MUX_B_CHANNEL_3=0x7
        I2C_MUX_B_CHANNEL_4=0x0    # not support
    fi
}

## Different variables by each project ::
function Variable_Setting_Porsche ()
{
    SFP_PORTS_AMOUNT=48
    QSFP_PORTS_AMOUNT=6
    ## MUX model
    mux_a="PCA9544"
    mux_b="PCA9544"
    MUX_Channel_Define    ## decide channel number by MUX model.

    ## MainBoard MCU and Fan
    I2C_MUX_CHANNEL_MCU=$I2C_MUX_A_CHANNEL_3
    FAN_AMOUNT=5
    MB_MCU_ADC_MONITOR_AMOUNT=5
    ADC_MONITOR_LABEL=("P0.2 (12V)" "P0.6 (3.3V)" "P0.1 (1.8V)" "P1.5 (1.2V)" "P0.7 (0.9V)" "P1.6 (0.V)")
    ## Multiphase Controller on MainBoard
    I2C_MUX_PMBUS=$I2C_MUX_B
    I2C_MUX_CHANNEL_PMBUS=$I2C_MUX_B_CHANNEL_3
    PMBUS_MB_A_ADDR=0x60
    PMBUS_MB_B_ADDR=0x09
    ## SYSTEM and front ports LED
    I2C_MUX_CHANNEL_SYSTEM_LED=$I2C_MUX_B_CHANNEL_1
    CPLD_LED_CONTROL=$CPLD_B_ADDR
    CPLD_LEDCR1_REG=0x0D
    CPLD_LEDCR2_REG=0x0E
    CPLD_LEDCR1_VALUE_DEFAULT=0x60  # SYS green blink & PWR green on
    CPLD_LEDCR1_VALUE_NORMAL=0x00   # SYS green on    & PWR green on
    CPLD_LEDCR1_VALUE_GREEN=0x00    # SYS green on    & PWR green on
    CPLD_LEDCR1_VALUE_AMBER=0x24    # SYS amber on    & PWR amber on
    CPLD_LEDCR1_VALUE_OFF=0x48      # SYS off         & PWR off
    CPLD_LEDCR1_VALUE_SYSTEM_ERROR_BLINK=0x80
    CPLD_LEDCR2_VALUE_NORMAL=0x12   # LOC off & FAN off
    CPLD_LEDCR2_VALUE_GREEN=0x10    # LOC off & FAN green on
    CPLD_LEDCR2_VALUE_AMBER=0x11    # LOC off & FAN amber on
    CPLD_LEDCR2_VALUE_OFF=0x12      # LOC off & FAN off
    CPLD_LEDCR2_VALUE_BLUE=0x02     # LOC on  & FAN off
    CPLD_MCR_REG=0x1
    CPLD_MCR_VALUE_NORMAL=0x07      # SLED disable + ports LED normal
    CPLD_MCR_VALUE_GREEN=0x05       # SLED enable + ports green and blue on
    CPLD_MCR_VALUE_AMBER=0x06
    CPLD_MCR_VALUE_OFF=0x04
    ## EEPROM of MainBoard
    I2C_MUX_MB_EEPROM=$I2C_MUX_A
    I2C_MUX_CHANNEL_MB_EEPROM=$I2C_MUX_A_CHANNEL_2
    I2C_MUX_CHANNEL_MB_EEPROM_WP=$I2C_MUX_B_CHANNEL_1
    CPLD_MCR2_CONTROL=$CPLD_B_ADDR
    CPLD_MCR2_REG=0x12
    CPLD_MCR2_EEPROM_WP_BIT=0x04
    ## PSU related
    I2C_MUX_CHANNEL_PSU_STATUS=$I2C_MUX_B_CHANNEL_1
    CPLD_PSR_CONTROL=$CPLD_B_ADDR
    CPLD_PSR_REG=0x15
    CPLD_PSR_A_PRESENT_BIT=0x8
    CPLD_PSR_B_PRESENT_BIT=0x4
    SHIFT_PRESENT_A_OFFSET=3
    SHIFT_PRESENT_B_OFFSET=2
    ## QSFP/SFP access related
    # Module select register.
    CPLD_A_MODULE_MCR_REG=0x04
    CPLD_B_MODULE_MCR_REG=0x02
    CPLD_C_MODULE_MCR_REG=0x05
    # Module present register.
    CPLD_A_MSRR_REG=0x08
    CPLD_B_MSRR_REG=0x05
    CPLD_C_MSRR1_REG=0x09
    CPLD_C_MSRR2_REG=0x0F
    # Module signal register
    QSFP_QRSTR_REG=0x10
    QSFP_MISRR_REG=0x08
    QSFP_QMSR_REG=0x17
    QSFP_QMLPMR_REG=0x18
}

function Variable_Setting_Bugatti ()
{
    QSFP_PORTS_AMOUNT=32
    SFP_PORTS_AMOUNT=0
    ## MUX model
    mux_a="PCA9544"
    mux_b="PCA9544"
    MUX_Channel_Define    ## decide channel number by MUX model.

    ## MainBoard MCU and Fan
    I2C_MUX_CHANNEL_MCU=$I2C_MUX_A_CHANNEL_3
    FAN_AMOUNT=5
    MB_MCU_ADC_MONITOR_AMOUNT=6
    ADC_MONITOR_LABEL=("P0.1 (12V)" "P0.2 (3.3V)" "P0.6 (1.8V)" "P0.7 (1.2V)" "P1.0 (1.0V)" "P1.1 (0.8V)" "P1.2 (3.3V)")
    ## Multiphase Controller on MainBoard
    I2C_MUX_PMBUS=$I2C_MUX_B
    I2C_MUX_CHANNEL_PMBUS=$I2C_MUX_B_CHANNEL_3
    PMBUS_MB_A_ADDR=0x60
    PMBUS_MB_B_ADDR=0x09
    I2C_MUX_CHANNEL_VOLTAGE_PATH=$I2C_MUX_B_CHANNEL_0
    CPLD_VOLTAGE_PATH=$CPLD_A_ADDR
    CPLD_PRCR_REG=0x0E
    CPLD_VRMCR_REG=0x0F
    ## SYSTEM and front ports LED . Due to Bugatti CPLD designer is different to others platform, so need MCR register to control LED.
    I2C_MUX_CHANNEL_SYSTEM_LED=$I2C_MUX_B_CHANNEL_0
    CPLD_LED_CONTROL=$CPLD_A_ADDR
    CPLD_LEDCR1_REG=0x05
    CPLD_LEDCR2_REG=0x06
    CPLD_LEDCR1_VALUE_DEFAULT=0x60
    CPLD_LEDCR1_VALUE_NORMAL=0x02    # SYS green on & PWR on
    CPLD_LEDCR1_VALUE_OFF=0x4A       # SYS off      & PWR off
    CPLD_LEDCR1_VALUE_SYSTEM_ERROR_BLINK=0x80
    CPLD_LEDCR2_VALUE_NORMAL=0x1a    # SLED_EN disable + LOC off & FAN off
    CPLD_LEDCR2_VALUE_BLUE=0x02      #                   LOC on  & FAN off
    CPLD_MCR_REG=0x07
    CPLD_MCR_VALUE_NORMAL=0x1D
    CPLD_MCR_VALUE_GREEN=0x0D
    CPLD_MCR_VALUE_AMBER=0x15
    CPLD_MCR_VALUE_OFF=0x05
    ## EEPROM of MainBoard
    I2C_MUX_MB_EEPROM=$I2C_MUX_A
    I2C_MUX_CHANNEL_MB_EEPROM=$I2C_MUX_A_CHANNEL_2
    I2C_MUX_CHANNEL_MB_EEPROM_WP=$I2C_MUX_B_CHANNEL_0
    CPLD_MCR2_CONTROL=$CPLD_A_ADDR
    CPLD_MCR2_REG=$CPLD_MCR_REG
    CPLD_MCR2_EEPROM_WP_BIT=0x04
    ## PSU related
    I2C_MUX_CHANNEL_PSU_STATUS=$I2C_MUX_B_CHANNEL_0
    CPLD_PSR_CONTROL=$CPLD_A_ADDR
    CPLD_PSR_REG=0x01
    CPLD_PSR_A_PRESENT_BIT=0x1
    CPLD_PSR_B_PRESENT_BIT=0x2
    SHIFT_PRESENT_A_OFFSET=0
    SHIFT_PRESENT_B_OFFSET=1
    ## QSFP/SFP access related
    # Module select register.
    CPLD_A_MODULE_MCR_REG=0x09
    CPLD_B_MODULE_MCR_REG=0x04
    CPLD_C_MODULE_MCR_REG=0x04
    # Module present register.
    CPLD_A_MSRR_REG=0x0B
    CPLD_B_MSRR1_REG=0x07
    CPLD_B_MSRR2_REG=0x08
    CPLD_C_MSRR1_REG=0x07
    CPLD_C_MSRR2_REG=0x08

}

function Variable_Setting_Jaguar ()
{
    SFP_PORTS_AMOUNT=48
    QSFP_PORTS_AMOUNT=8
    ## MUX model
    mux_a="PCA9544"
    mux_b="PCA9544"
    MUX_Channel_Define    ## decide channel number by MUX model.

    ## MainBoard MCU and Fan
    I2C_MUX_CHANNEL_MCU=$I2C_MUX_A_CHANNEL_3
    FAN_AMOUNT=5
    MB_MCU_ADC_MONITOR_AMOUNT=7
    ADC_MONITOR_LABEL=("P0.1 (12V)" "P0.2 (3.3V)" "P0.6 (1.8V)" "P0.7 (0.88V)" "P1.0 (0.8V)" "P1.1 (5V)" "P1.2 (3.3V)" "P1.6 (1.2V)")
    ## Multiphase Controller on MainBoard
    I2C_MUX_PMBUS=$I2C_MUX_B
    I2C_MUX_CHANNEL_PMBUS=$I2C_MUX_B_CHANNEL_3
    PMBUS_MB_A_ADDR=0x60
    PMBUS_MB_B_ADDR=0x09
    I2C_MUX_CHANNEL_VOLTAGE_PATH=$I2C_MUX_B_CHANNEL_1
    CPLD_VOLTAGE_PATH=$CPLD_B_ADDR
    CPLD_PRCR_REG=0x13
    CPLD_VRMCR_REG=0x14
    ## SYSTEM and front ports LED
    I2C_MUX_CHANNEL_SYSTEM_LED=$I2C_MUX_B_CHANNEL_1
    CPLD_LED_CONTROL=$CPLD_B_ADDR
    CPLD_LEDCR1_REG=0x0D
    CPLD_LEDCR2_REG=0x0E
    CPLD_LEDCR1_VALUE_DEFAULT=0x60
    CPLD_LEDCR1_VALUE_NORMAL=0x00    # SYS green on & PWR on
    CPLD_LEDCR1_VALUE_OFF=0x48       # SYS off      & PWR off
    CPLD_LEDCR1_VALUE_SYSTEM_ERROR_BLINK=0x80
    CPLD_LEDCR2_VALUE_NORMAL=0x12    # SLED_EN disable + LOC off & FAN off
    CPLD_LEDCR2_VALUE_GREEN=0x10     #                   LOC off & FAN green on
    CPLD_LEDCR2_VALUE_AMBER=0x11     #                   LOC off & FAN amber on
    CPLD_LEDCR2_VALUE_OFF=0x12       #                   LOC off & FAN off
    CPLD_LEDCR2_VALUE_BLUE=0x02      #                   LOC on  & FAN off
    CPLD_MCR_REG=0x01
    CPLD_MCR_VALUE_NORMAL=0x00
    CPLD_MCR_VALUE_GREEN=0x18        # SLED_EN enable + LED_force green,blue on
    CPLD_MCR_VALUE_AMBER=0x28
    CPLD_MCR_VALUE_OFF=0x38
    ## EEPROM of MainBoard
    I2C_MUX_MB_EEPROM=$I2C_MUX_A
    I2C_MUX_CHANNEL_MB_EEPROM=$I2C_MUX_A_CHANNEL_2
    I2C_MUX_CHANNEL_MB_EEPROM_WP=$I2C_MUX_B_CHANNEL_1
    CPLD_MCR2_CONTROL=$CPLD_B_ADDR
    CPLD_MCR2_REG=0x12
    CPLD_MCR2_EEPROM_WP_BIT=0x04
    ## PSU related
    I2C_MUX_CHANNEL_PSU_STATUS=$I2C_MUX_B_CHANNEL_1
    CPLD_PSR_CONTROL=$CPLD_B_ADDR
    CPLD_PSR_REG=0x15
    CPLD_PSR_A_PRESENT_BIT=0x8
    CPLD_PSR_B_PRESENT_BIT=0x4
    SHIFT_PRESENT_A_OFFSET=3
    SHIFT_PRESENT_B_OFFSET=2
    ## QSFP/SFP access related
    # Module select register.
    CPLD_A_MODULE_MCR_REG=0x04
    CPLD_B_MODULE_MCR_REG=0x02
    CPLD_C_MODULE_MCR_REG=0x05
    # Module present register.
    CPLD_A_MSRR_REG=0x09
    CPLD_B_MSRR1_REG=0x05
    CPLD_B_MSRR2_REG=0x09
    CPLD_C_MSRR1_REG=0x09
    CPLD_C_MSRR2_REG=0x0F
    # Module signal register
    QSFP_QRSTR_REG=0x10
    QSFP_MISRR_REG=0x08
    QSFP_QMSR_REG=0x17
    QSFP_QMLPMR_REG=0x18
}

function Variable_Setting_Gemini ()
{
    SFP_PORTS_AMOUNT=48
    QSFP_PORTS_AMOUNT=8
    ## MUX model
    mux_a="PCA9544"
    mux_b="PCA9548"
    MUX_Channel_Define    ## decide channel number by MUX model.

    ## MainBoard MCU and Fan
    I2C_MUX_CHANNEL_MCU=$I2C_MUX_A_CHANNEL_3
    FAN_AMOUNT=5
    MB_MCU_ADC_MONITOR_AMOUNT=9
    ADC_MONITOR_LABEL=("P0.1 (12V)" "P0.2 (3.3V)" "P0.6 (1.8V)" "P0.7 (0.88V)" "P1.0 (0.8V)" "P1.1 (0.9V_PLL)" "P1.2 (3.3V)" "P1.5 (0.9V_VDDA)" "P1.6 (1.1V)")
    ## Multiphase Controller on MainBoard
    I2C_MUX_PMBUS=$I2C_MUX_A
    I2C_MUX_CHANNEL_PMBUS=$I2C_MUX_A_CHANNEL_2
    PMBUS_MB_A_ADDR=0x60    ## TP53679
    PMBUS_MB_B_ADDR=0x09    ## TP40428
    PMBUS_MB_C_ADDR=0x5F    ## TP53679
    I2C_MUX_CHANNEL_VOLTAGE_PATH=$I2C_MUX_B_CHANNEL_1
    CPLD_VOLTAGE_PATH=$CPLD_B_ADDR
    CPLD_PRCR_REG=0x13
    ## SYSTEM and front ports LED
    I2C_MUX_CHANNEL_SYSTEM_LED=$I2C_MUX_B_CHANNEL_1
    CPLD_LED_CONTROL=$CPLD_B_ADDR
    CPLD_LEDCR1_REG=0x0D
    CPLD_LEDCR2_REG=0x0E
    CPLD_LEDCR1_VALUE_DEFAULT=0x60
    CPLD_LEDCR1_VALUE_NORMAL=0x00    # SYS green on & PWR on
    CPLD_LEDCR1_VALUE_OFF=0x48       # SYS off      & PWR off
    CPLD_LEDCR1_VALUE_SYSTEM_ERROR_BLINK=0x80
    CPLD_LEDCR2_VALUE_NORMAL=0x12    # SLED_EN disable + LOC off & FAN off
    CPLD_LEDCR2_VALUE_GREEN=0x10     #                   LOC off & FAN green on
    CPLD_LEDCR2_VALUE_AMBER=0x11     #                   LOC off & FAN amber on
    CPLD_LEDCR2_VALUE_OFF=0x12       #                   LOC off & FAN off
    CPLD_LEDCR2_VALUE_BLUE=0x02      #                   LOC on  & FAN off
    CPLD_MCR_REG=0x1
    CPLD_MCR_VALUE_NORMAL=0x00       # SLED disable + ports LED normal
    CPLD_MCR_VALUE_GREEN=0x18        # SLED enable + ports green and blue on
    CPLD_MCR_VALUE_AMBER=0x28
    CPLD_MCR_VALUE_OFF=0x08
    ## EEPROM of MainBoard
    I2C_MUX_MB_EEPROM=$I2C_MUX_B
    I2C_MUX_CHANNEL_MB_EEPROM=$I2C_MUX_B_CHANNEL_3
    I2C_MUX_CHANNEL_MB_EEPROM_WP=$I2C_MUX_B_CHANNEL_1
    CPLD_MCR2_CONTROL=$CPLD_B_ADDR
    CPLD_MCR2_REG=0x12
    CPLD_MCR2_EEPROM_WP_BIT=0x04
    ## PSU related
    I2C_MUX_CHANNEL_PSU_STATUS=$I2C_MUX_B_CHANNEL_1
    CPLD_PSR_CONTROL=$CPLD_B_ADDR
    CPLD_PSR_REG=0x15
    CPLD_PSR_A_PRESENT_BIT=0x8
    CPLD_PSR_B_PRESENT_BIT=0x4
    SHIFT_PRESENT_A_OFFSET=3
    SHIFT_PRESENT_B_OFFSET=2
    ## QSFP/SFP access related
    # Module select register.
    CPLD_A_MODULE_MCR_REG=0x04
    CPLD_B_MODULE_MCR_REG=0x02
    CPLD_C_MODULE_MCR_REG=0x05
    # Module present register. (based)
    CPLD_A_MSRR_REG=0x09
    CPLD_B_MSRR1_REG=0x05
    CPLD_B_MSRR2_REG=0x09
    CPLD_C_MSRR1_REG=0x09
    CPLD_C_MSRR2_REG=0x0F
    # Module signal register
    QSFP_QRSTR_REG=0x10
    QSFP_MISRR_REG=0x08
    QSFP_QMSR_REG=0x17
    QSFP_QMLPMR_REG=0x18

    # I/O Expander (from MB v3.0)
    IO_EXPANDER_1=0x22
    IO_EXPANDER_2=0x23
    IO_EXPANDER_3=0x38
}

function Variable_Setting_Aston()
{
    SFP_PORTS_AMOUNT=2
    QSFP_PORTS_AMOUNT=32

    ## MUX model
    mux_a="PCA9545"
    mux_b="PCA9548"
    MUX_Channel_Define    ## decide channel number by MUX model.

    ## MainBoard MCU and Fan
    I2C_MUX_CHANNEL_MCU=$I2C_MUX_A_CHANNEL_2
    FAN_AMOUNT=6
    MB_MCU_ADC_MONITOR_AMOUNT=11
    ADC_MONITOR_LABEL=(  "P3.5 (12V_STB)" "P3.6 (12V)" "P1.6 (4V)" "P4.0 (3.3V_STB)" "P4.1 (3.3V)" )
    ADC_MONITOR_LABEL+=( "P4.2 (1.8V)" "P4.3 (1.2V)" "P4.4 (1.0V)" "P4.5 (0.9V)" "P4.6 (0.8V)" )
    ADC_MONITOR_LABEL+=( "P4.7 (0.8V_CORE)" )

    ## Multiphase Controller on MainBoard
    I2C_MUX_PMBUS=$I2C_MUX_A
    I2C_MUX_CHANNEL_PMBUS=$I2C_MUX_A_CHANNEL_3
    PMBUS_MB_A_ADDR=0x66
    PMBUS_MB_B_ADDR=0x6A
    MPC_TPS536C7_NVM_CHECKSUM_REG=0xF0
    I2C_MUX_CHANNEL_VOLTAGE_PATH=$I2C_MUX_B_CHANNEL_0
    CPLD_VOLTAGE_PATH=$CPLD_A_ADDR
    CPLD_PRCR1_REG=0x13
    CPLD_PRCR2_REG=0x14

    ## main board CPLD - SW reset and hitless function inhibit register
    CPLD_SWRHFI_REG=0x22        ## Enable RST_NPU_nSYS_R function.
    CPLD_SW_RESET_ENABLE=0x3    ## Disable CPLD hitless function.

    ## SYSTEM and front ports LED.  ps.AM project design is different with others projects.
    I2C_MUX_CHANNEL_SYSTEM_LED=$I2C_MUX_B_CHANNEL_0
    CPLD_LED_CONTROL=$CPLD_A_ADDR
    CPLD_LEDCR1_REG=0x31
    CPLD_LEDCR2_REG=0x32
    ## For CPLD-A (SYS and PWR by MB CPLD-A / LOC by NPU CPLD-D) (PWR polling by CPLD-A in Aston)
    CPLD_LEDCR1_VALUE_DEFAULT=0x84
    #CPLD_LEDCR1_VALUE_NORMAL=0x24    # SYS green on & PWR green on & LOC off
    CPLD_LEDCR1_VALUE_NORMAL=0x20    # SYS green on & PWR off & LOC off
    CPLD_LEDCR1_VALUE_GREEN=0x24     # SYS green on & PWR green on & LOC off
    CPLD_LEDCR1_VALUE_RED=0x48       # SYS red on   & PWR red on   & LOC off
    CPLD_LEDCR1_VALUE_OFF=0x00       # SYS off      & PWR off      & LOC off
    CPLD_LEDCR1_VALUE_BLUE=0x01      # SYS off      & PWR off      & LOC on
    CPLD_LEDCR1_VALUE_SYSTEM_ERROR_BLINK=0xA0
    CPLD_LEDCR2_VALUE_NORMAL=0x11    # FAN green on
    CPLD_LEDCR2_VALUE_RED=0x12       # FAN red on
    CPLD_LEDCR2_VALUE_OFF=0x10       # FAN off
    ## For CPLD-B
    CPLD_B_LEDCR1_SLED_ENABLE=0x14     # CPLD_SYS_LED blink, SLED enable
    CPLD_B_LEDCR1_SLED_DISABLE=0x10    # CPLD_SYS_LED blink, SLED disable (for LED control test)
    ## For CPLD-C
    CPLD_C_LEDCR1_SLED_ENABLE=0x34     # CPLD_SYS_LED blink, SLED & SFP+ LED enable
    CPLD_C_LEDCR1_SLED_DISABLE=0x30    # CPLD_SYS_LED blink, SLED & SFP+ LED disable

    CPLD_MCR_REG=0x33
    CPLD_MCR_VALUE_NORMAL=0x0f       # ports LED normal
    CPLD_MCR_VALUE_RED=0x01          # ports red on
    CPLD_MCR_VALUE_GREEN=0x02        # ports green on
    CPLD_MCR_VALUE_BLUE=0x03         # ports blue on
    CPLD_MCR_VALUE_YELLOW=0x04       # ports yellow on
    CPLD_MCR_VALUE_CYAN=0x05         # ports cyan on
    CPLD_MCR_VALUE_MAGENTA=0x06      # ports magenta on
    CPLD_MCR_VALUE_WHITE=0x07        # ports white on
    CPLD_MCR_VALUE_OFF=0x00

    ## System LED Control
    ## 000x_xxxx  :  green & red off
    ## 001x_xxxx  :  green solid on
    ## 010x_xxxx  :  red solid on
    ## 011x_xxxx  :  green & red on
    ## 100x_xxxx  :  green blinking (4Hz)
    ## 101x_xxxx  :  red blinking (4Hz)
    ## 110x_xxxx  :  green & red blinking (4Hz)
    ## 111x_xxxx  :  TBD
    ## System LED Mask
    DIAG_SYS_LED_GREEN_ON_MASK=0x20
    DIAG_SYS_LED_AMBER_ON_MASK=0x40     ## For Aston, control red solid on for burn-in test.
    DIAG_SYS_LED_GREEN_BLINK_MASK=0x80
    DIAG_SYS_LED_AMBER_BLINK_MASK=0xA0  ## For Aston, control red blinking for burn-in test.

    ## EEPROM of MainBoard
    I2C_MUX_MB_EEPROM=$I2C_MUX_B
    I2C_MUX_CHANNEL_MB_EEPROM=$I2C_MUX_B_CHANNEL_3
    I2C_MUX_CHANNEL_MB_EEPROM_WP=$I2C_MUX_B_CHANNEL_0
    CPLD_MCR2_CONTROL=$CPLD_A_ADDR
    CPLD_MCR2_REG=0x01
    CPLD_MCR2_EEPROM_WP_BIT=0x02

    ## PSU related
    I2C_MUX_CHANNEL_PSU_STATUS=$I2C_MUX_B_CHANNEL_0
    CPLD_PSR_CONTROL=$CPLD_A_ADDR
    CPLD_PSR_REG=0x11
    CPLD_PSR_A_PRESENT_BIT=0x1
    CPLD_PSR_B_PRESENT_BIT=0x2
    SHIFT_PRESENT_A_OFFSET=0
    SHIFT_PRESENT_B_OFFSET=1

    ## QSFP/SFP access related
    # Module select register.
    CPLD_B_MODULE_MCR_REG=0x41
    CPLD_C_MODULE_MCR_REG=0x41
    # Module present register.
    CPLD_B_QSFPDD_PSR1_REG=0x44
    CPLD_B_QSFPDD_PSR2_REG=0x45
    CPLD_C_QSFPDD_PSR1_REG=0x44
    CPLD_C_QSFPDD_PSR2_REG=0x45
    CPLD_C_SFPPLUS_PSR_REG=0x4E
}

function Project_ID_Check ()
{
    # Proj Name   Proj ID
    # Cadillac    xxx0_0000 (0x0)
    # Mercedes    xxx0_0001 (0x1)
    # Mercedes3   xxx0_0010 (0x2)
    # Porsche     xxx0_0011 (0x3)
    # Bugatti     xxx0_0100 (0x4)
    # Bugatti2    xxx0_0111 (0x7)
    # Jaguar      xxx0_0101 (0x5)
    # AstonMartin xxx0_1000 (0x8)
    # Gemini      xxx0_1001 (0x9)

    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        ## read boardID by GPIO_15,14,16,18 to determine value. So check GPIO status bit_1 : 1 (=2) means high ; 0 (=0) means low.
        readGPIO_15=$( { /sbin/gpio r 15 | cut -c30- ; } 2>&1 )
        if [[ "$readGPIO_15" == "2" ]]; then
            readGPIO_15=1
        fi
        readGPIO_14=$( { /sbin/gpio r 14 | cut -c30- ; } 2>&1 )
        if [[ "$readGPIO_14" == "2" ]]; then
            readGPIO_14=1
        fi
        readGPIO_16=$( { /sbin/gpio r 16 | cut -c30- ; } 2>&1 )
        if [[ "$readGPIO_16" == "2" ]]; then
            readGPIO_16=1
        fi
        readGPIO_18=$( { /sbin/gpio r 18 | cut -c30- ; } 2>&1 )
        if [[ "$readGPIO_18" == "2" ]]; then
            readGPIO_18=1
        fi
        board_ID_bit=$( { echo $readGPIO_15$readGPIO_14$readGPIO_16$readGPIO_18 ; } 2>&1 )
        #echo $board_ID_bit
    #elif [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
    else    ## BDXDE
        if [[ ! -f "$GPIO_MUTEX_NODE" ]]; then
            touch $GPIO_MUTEX_NODE
            echo "480" > /sys/class/gpio/export    #GPIO_44
            echo "481" > /sys/class/gpio/export    #GPIO_45
            echo "482" > /sys/class/gpio/export    #GPIO_46
            echo "494" > /sys/class/gpio/export    #GPIO_58

            echo "454" > /sys/class/gpio/export    #GPIO_18 BMC_PRESENT_N
        fi
        bit3=$( { cat /sys/class/gpio/gpio494/value ; } 2>&1 )
        bit2=$( { cat /sys/class/gpio/gpio482/value ; } 2>&1 )
        bit1=$( { cat /sys/class/gpio/gpio481/value ; } 2>&1 )
        bit0=$( { cat /sys/class/gpio/gpio480/value ; } 2>&1 )
        board_ID_bit=$( { echo $bit3$bit2$bit1$bit0 ; } 2>&1 )

        gpio_bmc_present=$( { cat /sys/class/gpio/gpio454/value ; } 2>&1 )

        if (( 0 )); then
            rm $GPIO_MUTEX_NODE
            echo "480" > /sys/class/gpio/unexport
            echo "481" > /sys/class/gpio/unexport
            echo "482" > /sys/class/gpio/unexport
            echo "494" > /sys/class/gpio/unexport

            echo "454" > /sys/class/gpio/unexport
        fi
    fi

    case $board_ID_bit in
        0000)   PROJECT_NAME="CADILLAC";;
        0001)   PROJECT_NAME="MERCEDES";;
        0010)   PROJECT_NAME="MERCEDES";;
        0100)   PROJECT_NAME="BUGATTI";;    #Tomhawk
        0111)   PROJECT_NAME="BUGATTI"      #Trident3
                Variable_Setting_Bugatti
                ;;
        0011)   PROJECT_NAME="PORSCHE"
                Variable_Setting_Porsche
                ;;
        0101)   PROJECT_NAME="JAGUAR"
                Variable_Setting_Jaguar
                ;;
        1000)   PROJECT_NAME="ASTON"
                Variable_Setting_Aston
                ;;
        1001)   PROJECT_NAME="GEMINI"
                Variable_Setting_Gemini
                ;;
        1111)   ## if strap pin are full, will decide by CPLD register (0xFE [6:0])
                i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_B_CHANNEL_0
                data_result=$( { i2cget -y $I2C_BUS $CPLD_A_ADDR 0xFE ; } 2>&1 )
                board_ID_bit=$(( $data_result & 0x7f ))
                case $board_ID_bit in
                    0001001) PROJECT_NAME="GEMINI";;
                    *) PROJECT_NAME="??";;
                esac
                ;;
        *) board_ID="??"
           printf "\n[MFG Error Msg] Current project NOT support yet !!!\n"
           exit 1
           ;;
    esac
    echo " # current project is $PROJECT_NAME" > /tmp/projectCheck

    # sleep 1
}

function CPU_Model_Check ()
{
    cpu_name=$( cat /proc/cpuinfo | grep -m 1 "model name" | cut -c14- )
    if [[ "$cpu_name" == *"$CPU_RANGELEY"* ]]; then
        I2C_BUS=1
        ETHTOOL_NAME="eth0"
        MCU_UPGRADE_TTY_PORT="/dev/ttyS0"
        INTEL_MAGIC_NUMBER=0x1f418086
        #SPI_PDR_BASE_ADDRESS=""    # not support.
        SUPPORT_CPU="RANGELEY"
    elif [[ "$cpu_name" == *"$CPU_DENVERTON"* ]]; then
        I2C_BUS=0
        ETHTOOL_NAME="eth2"
        MCU_UPGRADE_TTY_PORT="/dev/ttyS1"
        INTEL_MAGIC_NUMBER=0x15e58086
        SPI_PDR_BASE_ADDRESS="0x00b86000"
        SUPPORT_CPU="DENVERTON"
    else
        for (( i = 0 ; i < ${#CPU_BDXDE[@]} ; i++ ))
        do
            if [[ "$cpu_name" == *"${CPU_BDXDE[$i]}"* ]]; then
                I2C_BUS=0
                ETHTOOL_NAME="eth0"
                MCU_UPGRADE_TTY_PORT="/dev/ttyS1"
                INTEL_MAGIC_NUMBER=0x15388086
                ## 20200707 add for detecting boot image (BIOS or Coreboot) to decide PDR region offset.
                if [ -d "/sys/firmware/efi/efivars" ] ; then
                    SPI_PDR_BASE_ADDRESS="0x00003000"        # BIOS enable GbE region, so PDR shift back 8KB size.
                else
                    SPI_PDR_BASE_ADDRESS="0x00001000"
                fi
                SUPPORT_CPU="BDXDE"
                break
            fi
        done

        if [[ "$SUPPORT_CPU" == "no" ]]; then
            echo "### Unrecognized CPU !!!  Will exit script immediately !!!"
            exit 1
        fi
    fi
}

function Check_SSD_Existance()
{
    ssd_lastpart=$( ls -al /dev/disk/by-id/ | grep "$SSD_LABEL" | sed -n '$p' | cut -d '/' -f 3 )
    if [[ -z "$ssd_lastpart" ]];then
        ssd_not_exist=$TRUE
    else
        ssd_not_exist=$FALSE
        ssd_location=$( { echo $ssd_lastpart | cut -c1-3 ; } 2>&1 )
    fi
}

function Check_EMMC_Existance()
{
    emmc_lastpart=$( ls -al /dev/disk/by-id/ | grep "$EMMC_LABEL" | sed -n '$p' | cut -d '/' -f 3 )
    if [[ -z "$emmc_lastpart" ]];then
        emmc_not_exist=$TRUE
    else
        emmc_not_exist=$FALSE

        ## 20200507 add for dynamic cut partition if it is pure empty eMMC
        emmc_partition_amount_check=$( ls -al /dev/disk/by-id/ | grep "$EMMC_LABEL" | wc -l )
        if (( $emmc_partition_amount_check == 1 )); then    ## means only sdX, no sdX1 or others.
            echo " ## eMMC is default no partition, will auto re-partition now ..."
            emmc_loc=$( ls -al /dev/disk/by-id/ | grep "$EMMC_LABEL" | sed -n '$p' | cut -d '/' -f 3 | cut -c1-3 )
            sgdisk -n 0:0:0 /dev/$emmc_loc
            mkfs.ext4 /dev/${emmc_loc}1
        fi
        ## Add End

        if [[ "$PROJECT_NAME" == "MERCEDES" ]] || [[ "$SUPPORT_CPU" == "RANGELEY" && "$PROJECT_NAME" == "BUGATTI" ]]; then
            # Check if disk is mounted already (maybe this script had run before), or mount up.
            check_mount_status=$( { mount | grep "$FOLDER_PATH_EMMC" ; } 2>&1 )
            if [ ! -z "$check_mount_status" ]; then
                echo " eMMC is already mounted."
            else
                if [ ! -d "$FOLDER_PATH_EMMC" ]; then
                    mkdir $FOLDER_PATH_EMMC
                fi

                emmc_partitionAmount="${emmc_lastpart: -1}"
                if (( $emmc_partitionAmount == 1 ));then    # only 1 partition, means log stored and rw test in the same partition. [Mercedes3 - Rangeley]
                    echo " Only 1 partition in eMMC, so that log and test will do in the same area."
                    mount /dev/$emmc_lastpart $FOLDER_PATH_EMMC

                    if [ ! -d "$FOLDER_PATH_EMMC/testLog" ]; then
                        mkdir $FOLDER_PATH_EMMC/testLog
                    fi
                    ln -s $FOLDER_PATH_EMMC/testLog $LOG_PATH_HOME
                fi
            fi
        else
            emmc_location=$( { echo $emmc_lastpart | cut -c1-3 ; } 2>&1 )
        fi
    fi
}

function Log_Folder_Check ()
{
    if [ ! -d "$LOG_PATH_HOME" ]; then mkdir "$LOG_PATH_HOME"; fi

    ## Mount to disk.
    check_mount_status=$( { mount | grep "$LOG_PATH_HOME" ; } 2>&1 )
    if [[ -z "$check_mount_status" ]]; then
        if (( $ONIE_ACCESS_WAY == 0 )); then               ## pure MFG partition layout.
            if [[ "$PROJECT_NAME" == "MERCEDES" ]] || [[ "$SUPPORT_CPU" == "RANGELEY" && "$PROJECT_NAME" == "BUGATTI" ]]; then   ## Mercedes & Bugatti1 only has 1 partition,
                echo "Mercedes skip mount eMMC here ... will mount in Check_EMMC_Existance function"
                #mount /dev/sda1 $LOG_PATH_HOME
            else                                           ## others project has multi-partitions, log part locate at 2nd partition and test area at sd*4.
                mount /dev/sda2 $LOG_PATH_HOME
            fi
        else
            ## Rules ::
            ## If both external SSD & eMMC exist and also has customized paritions, make logs stored in SSD first.
            ## If SSD exist     --- with log partition                               ---> stored @ SSD(3)
            ##                   -- without  partition --- but eMMC not exist        ---> stored @ SSD(1)
            ##                                          --(only for storage testing) ---> stored @ eMMC
            ## If SSD not exist --- eMMC with log partition                          ---> stored @ eMMC(3)
            ##                   -- eMMC without partition (ex: initramfs)           ---> stored @ eMMC(1)
            if [[ "$ssd_not_exist" == "$FALSE" ]]; then
                log_part=$( { sgdisk -p /dev/$ssd_location | grep "$ONIE_PARTITION_LOG_NAME" | awk '{print$1}' ; } 2>&1 )
                if [[ -z "$log_part" ]]; then
                    if [[ "$emmc_not_exist" == "$FALSE" ]]; then
                        log_part=$( { sgdisk -p /dev/$emmc_location | grep "$ONIE_PARTITION_LOG_NAME" | awk '{print$1}' ; } 2>&1 )
                        if [[ -z "$log_part" ]]; then
                            echo " # Log partition is not exist in SSD nor eMMC, so log folder will directly stored in the eMMC"
                            mount "/dev/$emmc_location""1" $LOG_PATH_HOME
                        else
                            mount /dev/$emmc_location$log_part $LOG_PATH_HOME
                            echo " # Log partition is mounted @ /dev/$emmc_location$log_part"
                        fi
                    else
                        echo " # Log partition is not exist in SSD nor eMMC, so log folder will directly stored in the SSD"
                        mount "/dev/$ssd_location""1" $LOG_PATH_HOME
                    fi
                else
                    mount /dev/$ssd_location$log_part $LOG_PATH_HOME
                    echo " # Log partition is mounted @ /dev/$ssd_location$log_part"
                fi
            else
                if [[ "$emmc_not_exist" == "$FALSE" ]]; then
                    log_part=$( { sgdisk -p /dev/$emmc_location | grep "$ONIE_PARTITION_LOG_NAME" | awk '{print$1}' ; } 2>&1 )
                    if [[ -z "$log_part" ]]; then
                        echo " # Log partition is not exist, log folder will directly stored in the MFG rootfs."
                        mount "/dev/$emmc_location""1" $LOG_PATH_HOME
                    else
                        mount /dev/$emmc_location$log_part $LOG_PATH_HOME
                        echo " # Log partition is mounted @ /dev/$emmc_location$log_part"
                    fi
                else
                    echo " # SSD & eMMC are not exist, so skip Log partition mount !"
                fi
            fi
        fi
    fi

    if [ ! -d "$LOG_PATH_I2C" ]; then mkdir "$LOG_PATH_I2C"; fi
    if [ ! -d "$LOG_PATH_STORAGE" ]; then mkdir "$LOG_PATH_STORAGE"; fi
    if [ ! -d "$LOG_PATH_OOB" ]; then mkdir "$LOG_PATH_OOB"; fi
    if [ ! -d "$LOG_PATH_HWMONITOR" ]; then mkdir "$LOG_PATH_HWMONITOR"; fi
    if [ ! -d "$LOG_PATH_MAC" ]; then mkdir "$LOG_PATH_MAC"; fi
    if [ ! -d "$LOG_PATH_FAN" ]; then mkdir "$LOG_PATH_FAN"; fi
}

### Main function ###
## Replace i2c-tools which support I2C Arbiter(PCA9614) function, as a backup action.
#if (( 0 )); then
#    if [[ ! -d "$BACKUP_ORIG_I2C_TOOLS" ]]; then
#        mkdir $BACKUP_ORIG_I2C_TOOLS
#        cp /usr/sbin/i2cdetect $BACKUP_ORIG_I2C_TOOLS
#        cp /usr/sbin/i2cdump $BACKUP_ORIG_I2C_TOOLS
#        cp /usr/sbin/i2cset $BACKUP_ORIG_I2C_TOOLS
#        cp /usr/sbin/i2cget $BACKUP_ORIG_I2C_TOOLS
#
#        cp -f /home/root/mfg/i2c-tools/i2c_arbiter/* /usr/sbin/
#        sync
#    fi
#fi

## Create symlink for common use commands
if [[ ! -f "$MFG_WORK_DIR/show_version" ]]; then
    ln -s $MFG_SOURCE_DIR/show_version.sh $MFG_WORK_DIR/show_version
    ln -s $MFG_SOURCE_DIR/hw_monitor.sh $MFG_WORK_DIR/hw_monitor
    ln -s $MFG_SOURCE_DIR/cpld_upgrade.sh $MFG_WORK_DIR/cpld_upgrade
    ln -s $MFG_SOURCE_DIR/mcu_fw_upgrade.sh $MFG_WORK_DIR/mcu_upgrade
    ln -s $MFG_SOURCE_DIR/diag_test.sh $MFG_WORK_DIR/diag_test
fi

## Check platform information
CPU_Model_Check
Project_ID_Check

## Create symlink for common use command.
if [[ ! -f "$MFG_WORK_DIR/sdk_start" ]]; then
    if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        ln -s $MFG_SOURCE_DIR/gemini_sdk_start.sh $MFG_WORK_DIR/sdk_start
    elif [[ "$PROJECT_NAME" == "ASTON" ]]; then
        ln -s $MFG_SOURCE_DIR/aston_sdk_start.sh $MFG_WORK_DIR/sdk_start
    elif [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        ln -s $MFG_SOURCE_DIR/porsche2_sdk_start.sh $MFG_WORK_DIR/sdk_start
    else
        echo " # temporary not set symlink for SDK to this project..."
    fi
fi

## Mount Folders
## Check SSD and eMMC every times, because storage test need.
Check_SSD_Existance
Check_EMMC_Existance
if [[ ! -f "$platform_init_flag" ]]; then
    Log_Folder_Check
fi

## Insert Modules for tool - eeupdate64e/lanconf64e/nvmupdate64e
if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    module_check=$( { lsmod | grep "iqvlinux" ; } 2>&1 )
    if [[ -z "$module_check" ]]; then
        insmod $MFG_WORK_DIR/intel_nvm_flash_update_tool/iqvlinux.ko
    fi
    if [[ ! -L "/lib64" ]]; then
        ln -s /lib /lib64
    fi

    ## check BMC exist or not
    if [[ ! -z "/dev/ipmi0" ]] && [[ "$gpio_bmc_present" == 0 ]];then
        # echo " # BMC exist"
        FLAG_USE_IPMI=$TRUE

        ## Diag-test for PT-4C mode usage
        DIAG_I2C_TEST_CHECK_BUFFER_TIME="5"        # minute
    else
        FLAG_USE_IPMI=$FALSE

        ## Diag-test for PT-4C mode usage
        DIAG_I2C_TEST_CHECK_BUFFER_TIME="2"        # minute
    fi
fi
