topdir			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
srctree			:= $(abspath $(topdir)/src)

ifeq ($(USE_PREBUILD_FPGA_DRV),yes)	
progs           :=
progs_new       = fhgw_fpga_app_new
else
progs			= fhgw_fpga_app 
progs_new       :=
endif
all: $(progs) $(progs_new)

fhgw_fpga_app:
	@make -C $(srctree)/fhgw_fpga_app/lib_code
	@make -C $(srctree)/fhgw_fpga_app/app_code
	@cp $(srctree)/fhgw_fpga_app/app_code/fhgw_fpga_dr_test_app $(topdir)/builds

fhgw_fpga_app_new:
	@make -C $(srctree)/fhgw_fpga_app_new/lib_code
	@make -C $(srctree)/fhgw_fpga_app_new/app_code
	@cp $(srctree)/fhgw_fpga_app_new/app_code/fhgw_fpga_dr_test_app $(topdir)/builds
