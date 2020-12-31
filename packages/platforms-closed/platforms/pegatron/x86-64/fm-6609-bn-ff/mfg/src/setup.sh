#!/bin/bash

if [ ! -h show_version ]; then
    ln -sf mfg_sources/show_version.sh show_version
fi

if [ ! -h cpld_upgrade ]; then
    ln -sf mfg_sources/cpld_upgrade.sh cpld_upgrade
fi

if [ ! -h hw_monitor ]; then
    ln -sf mfg_sources/hw_monitor.sh hw_monitor 
fi

if [ ! -h mcu_upgrade ]; then
    ln -sf mfg_sources/mcu_upgrade.sh mcu_upgrade 
fi

if [ ! -h diag_test ]; then
    ln -sf mfg_sources/diag_test.sh diag_test 
fi
