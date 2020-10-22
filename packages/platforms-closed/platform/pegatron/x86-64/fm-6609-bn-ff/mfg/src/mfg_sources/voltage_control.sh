#! /bin/bash

# I2C Tree:
# I2C MUX(A) PCA9544 0x72
#   channel 0 -- PSU(A) 0x58
#   channel 1 -- PSU(B) 0x59
# I2C MUX(B) PCA9544 0x73
#   channel 0 -- CPLD(A) 0x74
#   channel 3 -- TPS53679 0x60
#             -- TPS40428 0x09

source /home/root/mfg/mfg_sources/platform_detect.sh

config_mb="normal"
config_npu="normal"
#config_psu="normal"
test_round=0

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

function Power_Rail_Control()
{
    _channel=$1
    _cpld=$2
    _cpld_reg=$3

    if [[ "$PROJECT_NAME" == "BUGATTI" ]] || [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        value_normal=0x0
        value_pos=0x5
        value_neg=0xa
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        value_normal=0x20
        value_pos=0x65
        value_neg=0xAA
    fi

    # select I2C MUX(B) PCA9544 to channel
    i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $_channel
    usleep $I2C_ACTION_DELAY

    # set CPLD (A) Power Rail Control Register
    if [[ $config_mb == "normal" ]]; then
        # set 1.2V (PTP5) as normal
        # set 1.8V (PTP3) as normal
        Write_I2C_Device_Node $I2C_BUS $_cpld $_cpld_reg $value_normal

    elif [[ $config_mb == "positive" ]]; then
        # set 1.2V (PTP5) as +5%
        # set 1.8V (PTP3) as +5%
        Write_I2C_Device_Node $I2C_BUS $_cpld $_cpld_reg $value_pos

    elif [[ $config_mb == "negative" ]]; then
        # set 1.2V (PTP5) as -5%
        # set 1.8V (PTP3) as -5%
        Write_I2C_Device_Node $I2C_BUS $_cpld $_cpld_reg $value_neg
    fi

    # restore MUX channel to default
    i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG 0x0
    usleep $I2C_ACTION_DELAY
}

function TPS53679_Voltage_Set()
{
    if [[ "$PROJECT_NAME" == "BUGATTI" ]] || [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        ## select I2C MUX(B) PCA9544 to channel
        i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_VOLTAGE_PATH
        usleep $I2C_ACTION_DELAY

        ## set CPLD Voltage Regulator Mux Control Register to CPU path
        Write_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR $CPLD_VRMCR_REG 0x1
    fi

    # select I2C MUX(B) channel with multiphase controller
    i2cset -y $I2C_BUS $I2C_MUX_PMBUS $I2C_MUX_REG $I2C_MUX_CHANNEL_PMBUS
    usleep $I2C_ACTION_DELAY

    ## switch interface to PMBus
    Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS

    ## PMBus-A
    ## select channel A
    Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_A

    if [[ $config_mb == "normal" ]]; then
        # set VDD_CORE (PTP7) as normal
        # set margin off
        Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x88
    else
        if [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
            if [[ $config_mb == "positive" ]]; then      ## actually +3 value
                # set margin high
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x25 0x002a w
                usleep $I2C_ACTION_DELAY
                Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8

            elif [[ $config_mb == "negative" ]]; then    ## actually -3 value
                # set margin low
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x26 0x0024 w
                usleep $I2C_ACTION_DELAY
                Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x98
            fi
        elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
            if [[ $config_mb == "positive" ]]; then
                # set VDD_CORE (PTP7) as +5%
                # set margin high
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x25 0x002b w
                usleep $I2C_ACTION_DELAY
                Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8

            elif [[ $config_mb == "negative" ]]; then
                # set VDD_CORE (PTP7) as -5%
                # set margin low
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x26 0x0023 w
                usleep $I2C_ACTION_DELAY
                Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x98
            fi
        elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
            if [[ $config_mb == "positive" ]]; then      ## +5%
                # set margin high
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x24 0x002e w
                usleep $I2C_ACTION_DELAY
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x25 0x002e w
                usleep $I2C_ACTION_DELAY
                Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8

            elif [[ $config_mb == "negative" ]]; then    ## -3%
                # set margin low
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x26 0x0026 w
                usleep $I2C_ACTION_DELAY
                Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x98
            fi
        elif [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
            if [[ $config_mb == "+5" ]]; then
                # set VDD_CORE (0V9) as +5%
                # set margin high
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x25 0x008c w
                usleep $I2C_ACTION_DELAY
                Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8

            elif [[ $config_mb == "-5" ]]; then
                # set VDD_CORE (0V9) as -5%
                # set margin low
                i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x26 0x007a w
                usleep $I2C_ACTION_DELAY
                Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x98
            fi
        else
            echo " # Not support yet !"
        fi
    fi

    ## select channel B
    Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_B

    if [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        if [[ $config_mb == "normal" ]]; then
            i2cset -y $PEGA_I2C_BUS 0x60 0x25 0x0076 w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8

        elif [[ $config_mb == "positive" ]]; then       ## actually +3 value
            # set 0.8V (PTP9) as +3%
            # set margin high
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x24 0x007a w
            usleep $I2C_ACTION_DELAY
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x25 0x0079 w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8

        elif [[ $config_mb == "negative" ]]; then       ## actually +3 value
            # set 0.8V (PTP9) as -3%
            # set margin low
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x26 0x0071 w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x98
        fi
    elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
        if [[ $config_mb == "normal" ]]; then
            # set 0.8V (PTP9) as normal
            # set margin off
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x88

        elif [[ $config_mb == "positive" ]]; then
            # set 0.8V (PTP9) as +5%
            # set margin high
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x25 0x0077 w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8

        elif [[ $config_mb == "negative" ]]; then
            # set 0.8V (PTP9) as -5%
            # set margin low
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x26 0x0067 w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x98
        fi
    elif [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        if [[ $config_mb == "normal" ]]; then
            # set margin off
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x88
        elif [[ $config_mb == "positive" ]]; then      ## +3%
            # set margin high
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x25 0x0040 w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8
        elif [[ $config_mb == "negative" ]]; then      ## -3%
            # set margin low
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x26 0x003a w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x98
        fi
    elif [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
        if [[ $config_mb == "normal" ]]; then
            # set margin off
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x88
        elif [[ $config_mb == "+5" ]]; then
            # set margin high
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x25 0x008c w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0xa8
        elif [[ $config_mb == "-5" ]]; then
            # set margin low
            i2cset -y $I2C_BUS $PMBUS_MB_A_ADDR 0x26 0x007a w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR 0x01 0x98
        fi
    else
        echo " # Not support yet !"
    fi

    ## Due to Gemini has 2nd TP53679 (0x5f) , PMBus-C
    if [[ "$PROJECT_NAME" == "GEMINI" ]]; then
        ## switch interface to PMBus
        Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS

        ## select channel A
        Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_A

        if [[ $config_mb == "normal" ]]; then
            # set margin off
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR 0x01 0x88
        elif [[ $config_mb == "positive" ]]; then      ## +5.5%
            # set margin high
            i2cset -y $I2C_BUS $PMBUS_MB_C_ADDR 0x24 0x002c w
            usleep $I2C_ACTION_DELAY
            i2cset -y $I2C_BUS $PMBUS_MB_C_ADDR 0x25 0x002c w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR 0x01 0xa8
        elif [[ $config_mb == "negative" ]]; then      ## -9.1%
            # set margin low
            i2cset -y $I2C_BUS $PMBUS_MB_C_ADDR 0x2b 0x001f w
            usleep $I2C_ACTION_DELAY
            i2cset -y $I2C_BUS $PMBUS_MB_C_ADDR 0x26 0x001f w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR 0x01 0x98
        fi

        ## select channel B
        Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_B

        if [[ $config_mb == "normal" ]]; then
            # set margin off
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR 0x01 0x88
        elif [[ $config_mb == "positive" ]]; then      ## +10%
            # set margin high
            i2cset -y $I2C_BUS $PMBUS_MB_C_ADDR 0x24 0x0027 w
            usleep $I2C_ACTION_DELAY
            i2cset -y $I2C_BUS $PMBUS_MB_C_ADDR 0x25 0x0027 w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR 0x01 0xa8
        elif [[ $config_mb == "negative" ]]; then      ## -5%
            # set margin low
            i2cset -y $I2C_BUS $PMBUS_MB_C_ADDR 0x26 0x001b w
            usleep $I2C_ACTION_DELAY
            Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_C_ADDR 0x01 0x98
        fi
    fi

    ## switch interface back to SVID
    Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_A_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_SVID
}

function TPS40428_Voltage_Set()
{
    if [[ "$PROJECT_NAME" == "BUGATTI" ]] || [[ "$PROJECT_NAME" == "JAGUAR" ]]; then
        ## select I2C MUX(B) PCA9544 to channel
        i2cset -y $I2C_BUS $I2C_MUX_B $I2C_MUX_REG $I2C_MUX_CHANNEL_VOLTAGE_PATH
        usleep $I2C_ACTION_DELAY

        ## set CPLD Voltage Regulator Mux Control Register to CPU path
        Write_I2C_Device_Node $I2C_BUS $CPLD_A_ADDR $CPLD_VRMCR_REG 0x1
    fi

    ## PMBus-B
    i2cset -y $I2C_BUS $I2C_MUX_PMBUS $I2C_MUX_REG $I2C_MUX_CHANNEL_PMBUS
    usleep $I2C_ACTION_DELAY

    if [[ $config_mb == "normal" ]]; then
        # set 3.3V (PTP1) as normal
        # set margin off
        Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_B_ADDR 0x01 0x88

    elif [[ $config_mb == "positive" ]]; then
        # set 3.3V (PTP1) as +5%
        # set margin high
        if [[ "$PROJECT_NAME" == "JAGUAR" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]] || [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
            i2cset -y $I2C_BUS $PMBUS_MB_B_ADDR 0xd5 0x000d w
            usleep $I2C_ACTION_DELAY
        elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
            i2cset -y $I2C_BUS $PMBUS_MB_B_ADDR 0xd5 0x0010 w
            usleep $I2C_ACTION_DELAY
        else
            echo " # Not support yet !"
        fi
        Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_B_ADDR 0x01 0xa8

    elif [[ $config_mb == "negative" ]]; then
        # set 3.3V (PTP1) as -5%
        # set margin low
        if [[ "$PROJECT_NAME" == "JAGUAR" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]] || [[ "$PROJECT_NAME" == "PORSCHE" ]]; then
            i2cset -y $I2C_BUS $PMBUS_MB_B_ADDR 0xd6 0xfff0 w
            usleep $I2C_ACTION_DELAY
        elif [[ "$PROJECT_NAME" == "BUGATTI" ]]; then
            i2cset -y $I2C_BUS $PMBUS_MB_B_ADDR 0xd6 0xfff3 w
            usleep $I2C_ACTION_DELAY
        else
            echo " # Not support yet !"
        fi
        Write_I2C_Device_Node $I2C_BUS $PMBUS_MB_B_ADDR 0x01 0x98
    fi
}

function BDXDE_Voltage_Set ()
{
    ## ------ TPS53679 (0x63) --------
    ## PVCCIN (channel A)
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_A
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS             # switch interface to PMBus

    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0x80         # 1.82V
    elif [[ $config_npu == "positive" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x24 0x008e w
        usleep $I2C_ACTION_DELAY
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x25 0x008e w    # VID(8e): 1.91V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0xa8         # 1.911V
    elif [[ $config_npu == "negative" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x26 0x007c w    # VID(7c): 1.73V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0x98         # 1.729V
    fi

    ## P1V05 (channel B)
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_B
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS             # switch interface to PMBus

    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0x80         # 1.05V
    elif [[ $config_npu == "positive" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x25 0x003d w    # VID(3d): 1.10V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0xa8         # 1.1025V
    elif [[ $config_npu == "negative" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x26 0x0033 w    # VID(33): 1.00V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0x98         # 0.9975V
    fi

    ## ------ TPS53679 (0x64) --------
    ## P1V2_VDDQ (channel B)
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_B
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS             # switch interface to PMBus

    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0x80         # 1.2V
    elif [[ $config_npu == "positive" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_64_ADDR 0x25 0x004d w    # VID(4d): 1.26V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0xa8         # 1.26V
    elif [[ $config_npu == "negative" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_64_ADDR 0x26 0x0041 w    # VID(41): 1.14V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0x98         # 1.14V
    fi

    ## ------ CPLD GPIO (0x18) --------
    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x2 0x00
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x3 0x00
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x5 0x00       ### This is for BMC !!!
        fi
    elif [[ $config_npu == "positive" ]]; then
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x2 0x55         # P5V0_STBY 5.25V,  # P1V7 1.785V,  # P2V5     2.625V
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x3 0x55         # P3V3_STBY 3.465V, # P1V3 1.365V,  # P1V5_PCH 1.575V
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x5 0x55       ### This is for BMC !!!
        fi
    elif [[ $config_npu == "negative" ]]; then
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x2 0xaa         # P5V0_STBY 4.75V,  # P1V7 1.615V,  # P2V5     2.375V
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x3 0xaa         # P3V3_STBY 3.135V, # P1V3 1.235V,  # P1V5_PCH 1.425V
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x5 0xaa       ### This is for BMC !!!
        fi
    fi

    ## ---- for control BMC ----
    if (( $FLAG_USE_IPMI == "$TRUE" )); then
        # P1V2_AUX & P1V5_AUX
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x03 ; } 2>&1 )
        if [[ $config_npu == "normal" ]]; then
            write_data=$(( $data_result & 0x0F ))
        elif [[ $config_npu == "positive" ]]; then
            write_data=$(( $data_result & 0x0F | 0x50 ))
        elif [[ $config_npu == "negative" ]]; then
            write_data=$(( $data_result & 0x0F | 0xa0 ))
        fi
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x03 $write_data

        # P2V5_AUX
        data_result=$( { Read_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x05 ; } 2>&1 )
        if [[ $config_npu == "normal" ]]; then
            write_data=$(( $data_result & 0xfc ))
        elif [[ $config_npu == "positive" ]]; then
            write_data=$(( $data_result & 0xfc | 0x01 ))
        elif [[ $config_npu == "negative" ]]; then
            write_data=$(( $data_result & 0xfc | 0x02 ))
        fi
        Write_I2C_Device_Node $I2C_BUS $NPU_CONTROL_CHIP_ADDR 0x05 $write_data
    fi
}

function DNV_Voltage_Set ()
{
    ## ------ TPS53679 (0x63) --------
    ## PVCCSRAM (channel A)
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_A
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS             # switch interface to PMBus

    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0x80         # 1.15V
    elif [[ $config_npu == "+5" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x25 0x00c1 w    # VID(c1): 1.21V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0xa8         # 1.2075V
    elif [[ $config_npu == "-5" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x26 0x00a9 w    # VID(8d): 1.09V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0x98         # 1.729V
    fi

    ## PVNN (channel B)
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_B
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS             # switch interface to PMBus

    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0x80         # 1.05V
    elif [[ $config_npu == "+5" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x25 0x00ac w    # VID(ac): 1.105V
        usleep $I2C_ACTION_DELAY
        iWrite_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0xa8         # 1.1025V
    elif [[ $config_npu == "-5" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_63_ADDR 0x26 0x0096 w    # VID(96): 0.995V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_63_ADDR 0x1 0x98         # 0.9975V
    fi

    ## ------ TPS53679 (0x64) --------
    ## PVCCP (channel A)
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_A
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS             # switch interface to PMBus

    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0x80         # 1.2V
    elif [[ $config_npu == "+5" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_64_ADDR 0x25 0x00c1 w    # VID(c1): 1.21V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0xa8         # 1.26V
    elif [[ $config_npu == "-5" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_64_ADDR 0x26 0x00a9 w    # VID(8d): 1.09V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0x98         # 1.14V
    fi
    ## P1V2_VDDQ (channel B)
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR $PMBUS_CHANNEL_REG $PMBUS_CHANNEL_B
    Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR $PMBUS_INTERFACE_REG $PMBUS_INTERFACE_PMBUS             # switch interface to PMBus

    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0x80         # 1.2V
    elif [[ $config_npu == "+5" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_64_ADDR 0x25 0x00cb w    # VID(cb): 1.26V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0xa8         # 1.26V
    elif [[ $config_npu == "-5" ]]; then
        i2cset -y $I2C_BUS $PMBUS_NPU_64_ADDR 0x26 0x00b3 w    # VID(b3): 1.14V
        usleep $I2C_ACTION_DELAY
        Write_I2C_Device_Node $I2C_BUS $PMBUS_NPU_64_ADDR 0x1 0x98         # 1.14V
    fi

    ## ------ GPIO Expander (0x23) --------
    if [[ $config_npu == "normal" ]]; then
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x2 0x00         # P5V0_STBY 5.0V,   # PVPP  2.5V
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x3 0x00         # P3V3_STBY 3.3V,   # P1V05 1.05V
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x6 0x00
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x7 0x00
    elif [[ $config_npu == "+5" ]]; then
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x2 0x55         # P5V0_STBY 5.25V,  # PVPP  2.625V
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x3 0x55         # P3V3_STBY 3.465V, # P1V05 1.1025V
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x6 0x00
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x7 0x00
    elif [[ $config_npu == "-5" ]]; then
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x2 0xaa         # P5V0_STBY 4.75V,  # PVPP  2.375V
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x3 0xaa         # P3V3_STBY 3.135V, # P1V05 0.9975V
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x6 0x00
        Write_I2C_Device_Node $I2C_BUS $DNV_GPIO_EXPANDER_ADDR 0x7 0x00
    fi
}

#function PSU_Voltage_Set()
#{
#}

function Log_Record()
{
    if [[ "$test_round" == "0" ]]; then
        return
    fi

    testLog="$LOG_PATH_VOLTAGE/voltage_control_$test_round.log"
    if [ -f "$testLog" ]; then rm "$testLog"; fi

    echo "
    [MFG] voltage_control
    - mainboard: $config_mb" >> $testLog
    echo "
    - npu: $config_npu" >> $testLog
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


function Input_Get()
{
    input_string=$1

    IFS='=' read -ra input_parts <<< "$input_string"
    input_item=${input_parts[0]}
    input_value=${input_parts[1]}

    if [[ $input_item == "mainboard" ]] || [[ $input_item == "mb" ]]; then
        if [[ $input_value == "normal" ]] || [[ $input_value == "positive" ]] || [[ $input_value == "negative" ]]; then
            config_mb=$input_value
        else
            echo "  Invalid mainboard voltage setting!"
            Help_Message
            exit 1
        fi
    elif [[ $input_item == "npu" ]]; then
        if [[ $input_value == "normal" ]] || [[ $input_value == "positive" ]] || [[ $input_value == "negative" ]]; then
            config_npu=$input_value
        else
            echo "  Invalid npu voltage setting!"
            Help_Message
            exit 1
        fi
#   elif [[ $input_item == "psu" ]]; then
#        break;
    elif [[ $input_item == "test_round" ]]; then
        test_round=$input_value
    fi
}

function Input_Help()
{
    input_string=$1

    if [[ $input_string == "-h" ]] || [[ $input_string == "-help" ]] || [[ $input_string == "--h" ]] ||
       [[ $input_string == "--help" ]] || [[ $input_string == "?" ]]; then
        Help_Message
        exit 1
    fi
}

function Help_Message()
{
    echo ""
    echo "  [MFG] Voltage Control help message:"
    echo "    mainboard    [*normal/positive/negative]"
    echo "    npu          [*normal/positive/negative]"
    #    echo "    psu          [*normal/+3/+5/-3/-5]"
    echo "    testRound    [number (add to record and name the log file)]"
    echo ""
    echo "    Ex: ./voltage_control.sh mb=positive"
    echo "    Ex: ./voltage_control.sh mb=positive testRound=2"
    echo ""
}

#
# Main
#
if [ -z "$1" ]; then
    Help_Message
    exit 1
fi
Input_Help $1
Input_Get $1
Input_Get $2
Input_Get $3
Input_Get $4

Mutex_Check_And_Create
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
fi

## mainboard
if [[ "$PROJECT_NAME" == "BUGATTI" ]] || [[ "$PROJECT_NAME" == "JAGUAR" ]] || [[ "$PROJECT_NAME" == "GEMINI" ]]; then
    Power_Rail_Control $I2C_MUX_CHANNEL_VOLTAGE_PATH $CPLD_VOLTAGE_PATH $CPLD_PRCR_REG
fi

TPS53679_Voltage_Set
TPS40428_Voltage_Set

## npu
if [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    BDXDE_Voltage_Set
elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
    DNV_Voltage_Set
fi

## psu
#PSU_Voltage_Set

Log_Record

Mutex_Clean
if (( $FLAG_USE_IPMI == "$TRUE" )); then
    swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
fi

echo ""
echo "[MFG] voltage_control"
echo "  - mainboard: "$config_mb
echo "  - npu: "$config_npu"%"
#echo "  - psu: "$config_psu"%"
echo ""
