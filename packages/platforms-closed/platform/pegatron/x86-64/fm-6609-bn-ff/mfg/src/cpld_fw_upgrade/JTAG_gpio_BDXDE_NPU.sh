#
# To export GPIO for access
#
#  Base address of BDX is 436
#
#  (448)  GPIO_12   CPLD_USAGE  CPLD_CPU_TMS
#  (504)  GPIO_68   CPLD_USAGE  CPLD_CPU_TDI
#  (497)  GPIO_61   CPLD_USAGE  CPLD_CPU_TCK
#  (463)  GPIO_27   CPLD_USAGE  CPLD_CPU_TDO
#
#  (461)  GPIO_25   CPLD_USAGE  CPLD_DOWNLOAD_SEL
#
# NPU --- Broadwell-DE
echo "448" > /sys/class/gpio/export # TMS
echo "504" > /sys/class/gpio/export # TDI
echo "497" > /sys/class/gpio/export # TCK
echo "463" > /sys/class/gpio/export # TDO

echo "461" > /sys/class/gpio/export # DOWNLOAD_SEL
#
# To set GPIO directions
#
echo "out" > /sys/class/gpio/gpio448/direction
echo "out" > /sys/class/gpio/gpio504/direction
echo "out" > /sys/class/gpio/gpio497/direction
echo "in"  > /sys/class/gpio/gpio463/direction

echo 1 > /sys/class/gpio/gpio448/value         # remain output
echo 1 > /sys/class/gpio/gpio504/value         # remain output

echo "out"  > /sys/class/gpio/gpio461/direction
echo 1 > /sys/class/gpio/gpio461/value         # 1: via CPU GPIO ; default (0) is via JTAG

