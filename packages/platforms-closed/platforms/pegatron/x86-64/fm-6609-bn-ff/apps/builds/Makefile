topdir			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
srctree			:= $(abspath $(topdir)/src)
BASE_DIR	    := $(ONLBASE)/packages/platforms-closed/platforms/pegatron/FHGW/apps
progs           := fhgw_fpga_app
all: $(progs)

fhgw_fpga_app:
	@cp $(BASE_DIR)/builds/fhgw_fpga_dr_test_app $(topdir)/builds
	@cp $(BASE_DIR)/src/prebuild/fhgw_fpga_app $(topdir)/builds
	@cp $(BASE_DIR)/src/script/fhgw_fpga_startup.sh $(topdir)/builds
