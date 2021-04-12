KERNELS := onl-kernel-4.19-lts-x86-64-all:amd64
KMODULES := src
VENDOR := pegatron
BASENAME := x86-64-pegatron-fm-6609-bn-ff
ARCH := x86_64
BASE_DIR	:= $(ONL)/packages/platforms-closed/platforms/pegatron/FHGW
PREBUILD_FPGA_MODULES := $(BASE_DIR)/modules/fpga
PREBUILD_CVP_MODULES := $(BASE_DIR)/modules/cvp
KERNEL_MBUILD := $(shell onlpm --find-dir $(KERNELS) mbuilds)
KERNELRELEASE := $(shell cat $(KERNEL_MBUILD)/include/config/kernel.release 2> /dev/null)
SUBDIR := "onl/$(VENDOR)/$(BASENAME)"
DIST_DIR := "lib/modules/$(KERNELRELEASE)/$(SUBDIR)"

modules:
	rm -rf lib
ifeq ($(USE_PREBUILD_FPGA_DRV),yes)	
	if [ ! -d $(DIST_DIR) ]; then \
		mkdir -p $(DIST_DIR); \
	fi
	cp $(PREBUILD_FPGA_MODULES)/fhgw_fpga_drv_1v4.ko $(DIST_DIR)/fhgw_fpga_drv.ko
else
	ARCH=$(ARCH) $(ONL)/tools/scripts/kmodbuild.sh "$(KERNELS)" "$(KMODULES)" "$(SUBDIR)" "$(KINCLUDES)"
endif
