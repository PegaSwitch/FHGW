#! /bin/bash
# This script is to set GPIO direction
#
# To export GPIO for access
#
#  (197)  GPIOS_1   CPLD_USAGE  TDI_CPLD
#  (198)  GPIOS_2   CPLD_USAGE  TCK_CPLD
#  (199)  GPIOS_3   CPLD_USAGE  TMS_CPLD
#  (212)  GPIOS_16  CPLD_USAGE  TDO_CPLD
#
echo "197" > /sys/class/gpio/export
echo "198" > /sys/class/gpio/export
echo "199" > /sys/class/gpio/export
echo "212" > /sys/class/gpio/export

#
# To set GPIO directions
#
echo "out" > /sys/class/gpio/gpio197/direction
echo "out" > /sys/class/gpio/gpio198/direction
echo "out" > /sys/class/gpio/gpio199/direction
echo "in"  > /sys/class/gpio/gpio212/direction
