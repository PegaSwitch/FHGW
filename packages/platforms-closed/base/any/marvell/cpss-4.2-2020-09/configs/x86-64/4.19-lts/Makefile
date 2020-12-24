THIS_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
include $(ONL)/make/config.mk

export ARCH := x86
ifndef CPSS_TARGET_DIR
CPSS_TARGET_DIR := $(THIS_DIR)
endif

include ../../../config.mk

CPSS_VERSION := CPSS_4.2_2020_09
CPSS_VERSION_SUFFIX := _013
CPSS_BRANCH := cpss_4.2

include $(ONLBASE)/packages/platforms-closed/base/any/marvell/build.mk
