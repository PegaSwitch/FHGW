MFG_BUILD_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
KERNEL := onl-kernel-4.19-lts-x86-64-all:amd64

include $(ONL)/make/config.amd64.mk
include $(ONLBASE)/packages/platforms-closed/base/any/mfg-utils/builds/mem_tester/Makefile
