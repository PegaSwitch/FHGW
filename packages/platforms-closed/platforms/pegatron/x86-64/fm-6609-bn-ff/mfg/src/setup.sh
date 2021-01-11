#!/bin/bash

MFG_WORK_DIR="/root/mfg"
MFG_SOURCE_DIR="/root/mfg/mfg_sources"

TELNET_DEV="ma1"

echo "========= PEGA MFG Customized ======="

echo 3 > /proc/sys/kernel/printk

export TZ='Asia/Taipei'

check_ip_exist=$( { ifconfig $TELNET_DEV | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}' ; } 2>&1 )
if [ -z "$check_ip_exist" ]; then
    ifconfig $TELNET_DEV 192.168.1.1 up
    echo " # No DHCP link, so manual config $TELNET_DEV IP as 192.168.1.1"
fi

if [ ! -L "${MFG_WORK_DIR}/show_version" ]; then
    ln -s ${MFG_SOURCE_DIR}/show_version.sh ${MFG_WORK_DIR}/show_version
fi
if [[ ! -L "${MFG_WORK_DIR}/hw_monitor" ]]; then
    ln -s ${MFG_SOURCE_DIR}/hw_monitor.sh ${MFG_WORK_DIR}/hw_monitor
fi
if [[ ! -L "${MFG_WORK_DIR}/cpld_upgrade" ]]; then
    ln -s ${MFG_SOURCE_DIR}/cpld_upgrade.sh ${MFG_WORK_DIR}/cpld_upgrade
fi
if [[ ! -L "${MFG_WORK_DIR}/mcu_upgrade" ]]; then
    ln -s ${MFG_SOURCE_DIR}/mcu_fw_upgrade.sh ${MFG_WORK_DIR}/mcu_upgrade
fi
if [[ ! -L "${MFG_WORK_DIR}/diag_test" ]]; then
    ln -s ${MFG_SOURCE_DIR}/diag_test.sh ${MFG_WORK_DIR}/diag_test
fi
echo "mount /tmp to tmpfs"
mount -t tmpfs tmpfs /tmp
echo "set uart path to uart 1"
i2cset -y 7 0x75 0x14 0x27
echo 453 > /sys/class/gpio/export
echo 0 > /sys/class/gpio/gpio453/value
echo "initialize FHGW platform"
source ${MFG_WORK_DIR}/platform_initialization/platform_init_FHGW.sh
echo "========= PEGA MFG Customized Done ======="
