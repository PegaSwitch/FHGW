#! /bin/bash
# This script is to set GPIO direction
#
# To export GPIO for access
#
#  (468=436+32)  U13 GPIOS_32   CPLD_USAGE  TDI_CPLD
#  (460=436+24)  U15 GPIOS_24   CPLD_USAGE  TCK_CPLD
#  (486=436+50)  U14 GPIOS_50   CPLD_USAGE  TMS_CPLD
#  (442=436+ 6)  U12 GPIOS_6    CPLD_USAGE  TDO_CPLD
#
echo "442" > /sys/class/gpio/export
echo "460" > /sys/class/gpio/export
echo "468" > /sys/class/gpio/export
echo "486" > /sys/class/gpio/export

#
# To set GPIO directions
#
echo "out" > /sys/class/gpio/gpio486/direction
echo "out" > /sys/class/gpio/gpio468/direction
echo "out" > /sys/class/gpio/gpio460/direction
echo "in"  > /sys/class/gpio/gpio442/direction
