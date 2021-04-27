#!/bin/bash
#lspci -vvv
rmmod altera_cvp
rmmod fhgw_fpga_drv
mv /lib/modules/4.19.81-OpenNetworkLinux/onl/pegatron/x86-64-pegatron-fm-6609-bn-ff/fhgw_fpga_top_eCPRI_6lanes.core.rbf /root/fhgw_fpga_top.core.rbf
mv /lib/modules/4.19.81-OpenNetworkLinux/onl/pegatron/x86-64-pegatron-fm-6609-bn-ff/altera_cvp.ko /root
mv /lib/modules/4.19.81-OpenNetworkLinux/onl/pegatron/x86-64-pegatron-fm-6609-bn-ff/fhgw_fpga_drv.ko /root
echo "========= load the cvp module ======="
insmod /root/altera_cvp.ko
echo "========= dd command ======="
dd if=/root/fhgw_fpga_top.core.rbf of=/dev/altera_cvp bs=4K
echo "Waiting for 2 seconds..."
sleep 2
echo "========= unload cvp module ======="
rmmod altera_cvp
echo "========= load the fhgw fpga module ======="
insmod /root/fhgw_fpga_drv.ko
