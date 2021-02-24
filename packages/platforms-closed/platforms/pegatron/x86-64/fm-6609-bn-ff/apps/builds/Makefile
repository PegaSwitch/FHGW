topdir			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
srctree			:= $(abspath $(topdir)/src)

progs			= fhgw_fpga_app

all: $(progs)

fhgw_fpga_app:
	@make -C $(srctree)/fhgw_fpga_app/lib_code
	@make -C $(srctree)/fhgw_fpga_app/app_code
	@cp $(srctree)/fhgw_fpga_app/app_code/fhgw_fpga_dr_test_app $(topdir)/builds
