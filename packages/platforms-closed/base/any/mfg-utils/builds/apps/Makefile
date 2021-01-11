topdir			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
srctree			:= $(abspath $(topdir)/../src/apps/src)
builddir		:= $(MFG_BUILD_DIR)/BUILD/$(ONL_DEBIAN_SUITE)/$(TOOLCHAIN)

all:

#include $(topdir)/apps/linux.debug.mk
#
#INCLUDES		+=
#CPPFLAGS		+=
#CFLAGS			+=
#CFLAGS_D		+=
#LDFLAGS			+=
#LDFLAGS_D		+=
#
#EXTRA_CLEAN		+=
#EXTRA_EXCLUDE_TARGETS	+=
#
#modules-y		+= $(srctree)/mii-tool
#modules-y		+= $(srctree)/ispvm
#modules-y		+= $(srctree)/onie_syseeprom
#modules-y		+= $(srctree)/uart_to_i2c
#
#include $(topdir)/apps/nonrecursive.mk
#
#quiet_cmd_cp		?= UPDATE  $@
#      cmd_cp		?= set -e; cp $< $@
#
#$(MFG_BUILD_DIR)/%: $(OBJ_DIR)/%
#	$(call cmd,cp)
#
#ifneq ($(apps_all),)
#all: $(apps_all:%=$(MFG_BUILD_DIR)/%)
#else
##all: $(libs_all:%=$(OBJ_DIR)/lib%.$(LIB_EXT))
#endif
#