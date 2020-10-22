#
# Marvell SDK build makefile
#

ifndef KERNEL
$(error $$KERNEL must be set)
endif

ifndef CPSS_PATCH_DIR
$(error $$CPSS_PATCH_DIR must be set)
endif

ifndef CPSS_PATCH_SERIES_FILE
    ifndef CPSS_PATCH_SERIES
        CPSS_PATCH_SERIES = series
    endif
    CPSS_PATCH_SERIES_FILE = $(CPSS_PATCH_DIR)/$(CPSS_PATCH_SERIES)
endif

#
#
#

ONL_CPSS := $(ONLBASE)/packages/platforms-closed/base/any/marvell

ifndef CPSS_NAME
CPSS_NAME := cpss_release_git_$(CPSS_VERSION)$(CPSS_VERSION_SUFFIX)
endif
ifndef CPSS_ARCHIVE_EXT
CPSS_ARCHIVE_EXT := tar
endif
ifndef CPSS_ARCHIVE_NAME
CPSS_ARCHIVE_NAME := $(CPSS_NAME).$(CPSS_ARCHIVE_EXT)
endif
CPSS_ARCHIVE_PATH := $(ONL_CPSS)/archives/$(CPSS_ARCHIVE_NAME)
ifndef CPSS_ARCHIVE_SITE
CPSS_ARCHIVE_SITE := http://10.2.3.6
endif
ifndef CPSS_ARCHIVE_URL
CPSS_ARCHIVE_URL := $(CPSS_ARCHIVE_SITE)/sdk/cpss/$(CPSS_ARCHIVE_NAME)
endif
CPSS_SOURCE_DIR := $(CPSS_TARGET_DIR)/cpss
K_HEADER_SOURCE := $(ONL)/REPO/$(ONL_DEBIAN_SUITE)/extracts/$(subst :,_,$(KERNEL))/usr/share/onl/packages/$(lastword $(subst :, ,$(KERNEL)))/$(firstword $(subst :, ,$(KERNEL)))/mbuilds/include

ifndef CPSS_BUILD_OPTS
CPSS_BUILD_OPTS := TARGET=ia64 FAMILY=DX
endif
ifndef CPSS_BUILD_TARGET
CPSS_BUILD_TARGET := appDemo
endif

.PHONY : extract patch config build

#
# fetch
#

$(CPSS_ARCHIVE_PATH):
ifeq ($(CPSS_HAVE_SOURCE),yes)
	if [ ! -d $(ONL_CPSS)/archives ]; then mkdir -p $(ONL_CPSS)/archives; fi
	cd $(ONL_CPSS)/archives && wget $(CPSS_ARCHIVE_URL)
endif

#
# extract
#

$(CPSS_TARGET_DIR)/.EXTRACTED: $(CPSS_ARCHIVE_PATH)
	mkdir -p $(CPSS_TARGET_DIR)
ifeq ($(CPSS_HAVE_SOURCE),yes)
	cd $(CPSS_TARGET_DIR) && tar xvf $(CPSS_ARCHIVE_PATH)
	cd $(CPSS_SOURCE_DIR) && git checkout $(CPSS_BRANCH)
endif
	touch $(CPSS_TARGET_DIR)/.EXTRACTED

extract: $(CPSS_TARGET_DIR)/.EXTRACTED

#
# patch
#

$(CPSS_TARGET_DIR)/.PATCHED: $(CPSS_TARGET_DIR)/.EXTRACTED
ifeq ($(CPSS_HAVE_SOURCE),yes)
	cd $(CPSS_SOURCE_DIR);						\
	if [ -f $(CPSS_PATCH_SERIES_FILE) ]; then			\
	    for p in `cat $(CPSS_PATCH_SERIES_FILE)`; do		\
	        git am $(CPSS_AM_OPTS) $(CPSS_PATCH_DIR)/$$p;		\
	    done;							\
	fi;
endif
	touch $(CPSS_TARGET_DIR)/.PATCHED

patch: $(CPSS_TARGET_DIR)/.PATCHED

#
# config
#
#  To allow build CPSS, we need to have specified Linux kernel header file.
#  To achieve this requirement, we can copy Linux kernel "uapi" header files
#  from ONL kernel package directly, however, below modification are required:
#
#    - In kernle header files, remove lines which contain
#      "#include <linux/compiler.h>", or just provide
#      a dummy empty "compiler.h" file under linux folder
#    - Same as above but use "compiler_types.h" instead of "compiler.h"
#    - Remove all "__user" modifiler in Linux header file, or
#      provide "CPSS_USER_CFLAGS=-D__user= " while build CPSS by its Makefile.

$(CPSS_TARGET_DIR)/.CONFIGED: $(CPSS_TARGET_DIR)/.PATCHED
ifeq ($(CPSS_HAVE_SOURCE),yes)
	mkdir -p $(CPSS_TARGET_DIR)/linux 
	cd $(CPSS_TARGET_DIR)/linux && cp -a $(K_HEADER_SOURCE)/uapi/* .
	cd $(CPSS_TARGET_DIR)/linux/linux && touch compiler.h
	cd $(CPSS_TARGET_DIR)/linux/linux && touch compiler_types.h
endif
	touch $(CPSS_TARGET_DIR)/.CONFIGED

config: $(CPSS_TARGET_DIR)/.CONFIGED

#
# build
#

CPSS_MAKE := $(MAKE) -C $(CPSS_SOURCE_DIR)
CPSS_OUTPUT := $(CPSS_TARGET_DIR)/cpss/compilation_root/$(CPSS_VERSION_MAJOR)/ia64_DX

build: config
ifeq ($(CPSS_HAVE_SOURCE),yes)
	$(CPSS_MAKE) KERNEL_INC_PATH=$(CPSS_TARGET_DIR)/linux \
	             CPSS_USER_CFLAGS=-D__user= \
	             $(CPSS_BUILD_OPTS) $(CPSS_BUILD_TARGET)
else
	mkdir -p $(CPSS_OUTPUT)
	cp $(ONL_CPSS)/$(CPSS)/prebuilt/* $(CPSS_OUTPUT)
endif

.DEFAULT_GOAL := build
