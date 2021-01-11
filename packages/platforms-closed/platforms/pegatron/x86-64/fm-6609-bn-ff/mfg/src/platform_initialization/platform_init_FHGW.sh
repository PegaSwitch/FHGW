#! /bin/bash

## source ${HOME}/mfg/mfg_sources/platform_detect.sh
I2C_BUS_MUX_B_CHANNEL_2=0x7
CPLD_B_ADDR=0x75
CPLD_B_MSRR2_REG=0x03           # ~ 0x06 : 8 ecpri port
CPLD_B_QSFP_REG=0x07
CPLD_B_SFPPLUS_REG=0x08
I2C_ACTION_DELAY=0.1

## port 1 ~ 8
i2cset -y $I2C_BUS_MUX_B_CHANNEL_2 $CPLD_B_ADDR $CPLD_B_MSRR2_REG 0x00
sleep $I2C_ACTION_DELAY
i2cset -y $I2C_BUS_MUX_B_CHANNEL_2 $CPLD_B_ADDR 0x04 0x00
sleep $I2C_ACTION_DELAY
i2cset -y $I2C_BUS_MUX_B_CHANNEL_2 $CPLD_B_ADDR 0x05 0x00
sleep $I2C_ACTION_DELAY
i2cset -y $I2C_BUS_MUX_B_CHANNEL_2 $CPLD_B_ADDR 0x06 0x00
sleep $I2C_ACTION_DELAY

## port 9
ret_val=$( { i2cget -y $I2C_BUS_MUX_B_CHANNEL_2 $CPLD_B_ADDR $CPLD_B_QSFP_REG ; } 2>&1 )
sleep $I2C_ACTION_DELAY
new_val=$(( $ret_val | 0x01 ))
i2cset -y $I2C_BUS_MUX_B_CHANNEL_2 $CPLD_B_ADDR $CPLD_B_QSFP_REG $new_val
sleep $I2C_ACTION_DELAY

## port 10
ret_val=$( { i2cget -y $I2C_BUS_MUX_B_CHANNEL_2 $CPLD_B_ADDR $CPLD_B_SFPPLUS_REG ; } 2>&1 )
sleep $I2C_ACTION_DELAY
new_val=$(( $ret_val & 0xf7 ))
i2cset -y $I2C_BUS_MUX_B_CHANNEL_2 $CPLD_B_ADDR $CPLD_B_SFPPLUS_REG $new_val
sleep $I2C_ACTION_DELAY

echo " # FHGW # Enable Tx : Done"


