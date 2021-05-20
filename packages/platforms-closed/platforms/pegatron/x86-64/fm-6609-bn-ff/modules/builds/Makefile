KERNELS := onl-kernel-4.19-lts-x86-64-all:amd64
KMODULES := src
VENDOR := pegatron
BASENAME := x86-64-pegatron-fm-6609-bn-ff
ARCH := x86_64
BASE_DIR	:= $(ONLBASE)/packages/platforms-closed/platforms/pegatron/FHGW
BASE_FPGA_MODULES := $(BASE_DIR)/modules/fpga/builds
PREBUILD_FPGA_MODULES := $(BASE_DIR)/modules/fpga/prebuild
PREBUILD_FPGA_FIRMWARE := $(BASE_DIR)/firmwares/fpga
PREBUILD_CVP_MODULES := $(BASE_DIR)/modules/cvp
KERNEL_MBUILD := $(shell onlpm --find-dir $(KERNELS) mbuilds)
KERNELRELEASE := $(shell cat $(KERNEL_MBUILD)/include/config/kernel.release 2> /dev/null)
SUBDIR := "onl/$(VENDOR)/$(BASENAME)"
DIST_DIR := "lib/modules/$(KERNELRELEASE)/$(SUBDIR)"

modules:
	rm -rf lib
	if [ ! -d $(DIST_DIR) ]; then \
		mkdir -p $(DIST_DIR); \
	fi
ifeq ($(USE_PREBUILD_FPGA_DRV),yes)	
	cp $(PREBUILD_FPGA_MODULES)/fhgw_fpga_drv_1v4.ko $(DIST_DIR)/fhgw_fpga_drv.ko
	cp $(PREBUILD_FPGA_MODULES)/altera_cvp.ko $(DIST_DIR)
else
	cp $(BASE_FPGA_MODULES)/$(DIST_DIR)/*.ko $(DIST_DIR)
endif
	cp $(PREBUILD_FPGA_FIRMWARE)/* $(DIST_DIR)	
