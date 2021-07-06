CPSS_ROOT	= cpss/compilation_root
CPSS_VER	= cpss_4.2/ia64_DX
CPSS_FILES	= appDemo appDemo.map version_info.c
BASE_DIR	= $(ONLBASE)/packages/platforms-closed/platforms/pegatron/FHGW
SDK_BASE_DIR	= $(BASE_DIR)/sdk/builds
FIRMWARE_BASE_DIR	= $(BASE_DIR)/firmwares
CPLD_FW_ROOT = firmware/cpld
MCU_FW_ROOT = firmware/mcu
BIOS_FW_ROOT = firmware/bios
INTEL_NVM_FW_ROOT = firmware/intel_nvm


all:
	mkdir -p $(ONL_DEBIAN_SUITE)/$(CPSS_ROOT)
	for f in $(CPSS_FILES); do					\
	    cp $(SDK_BASE_DIR)/$(ONL_DEBIAN_SUITE)/$(CPSS_ROOT)/$(CPSS_VER)/$$f $(ONL_DEBIAN_SUITE)/$(CPSS_ROOT);						\
	done
	if [ ! -d $(ONL_DEBIAN_SUITE)/$(CPLD_FW_ROOT) ]; then \
		mkdir -p $(ONL_DEBIAN_SUITE)/$(CPLD_FW_ROOT); \
	fi
	cp $(FIRMWARE_BASE_DIR)/cpld/* $(ONL_DEBIAN_SUITE)/$(CPLD_FW_ROOT);
	if [ ! -d $(ONL_DEBIAN_SUITE)/$(MCU_FW_ROOT) ]; then \
		mkdir -p $(ONL_DEBIAN_SUITE)/$(MCU_FW_ROOT); \
	fi
	cp $(FIRMWARE_BASE_DIR)/mcu/* $(ONL_DEBIAN_SUITE)/$(MCU_FW_ROOT);
	if [ ! -d $(ONL_DEBIAN_SUITE)/$(BIOS_FW_ROOT) ]; then \
		mkdir -p $(ONL_DEBIAN_SUITE)/$(BIOS_FW_ROOT); \
	fi
	cp $(FIRMWARE_BASE_DIR)/bios/* $(ONL_DEBIAN_SUITE)/$(BIOS_FW_ROOT);
	if [ ! -d $(ONL_DEBIAN_SUITE)/$(INTEL_NVM_FW_ROOT) ]; then \
		mkdir -p $(ONL_DEBIAN_SUITE)/$(INTEL_NVM_FW_ROOT); \
	fi
	cp $(FIRMWARE_BASE_DIR)/intel_nvm/* $(ONL_DEBIAN_SUITE)/$(INTEL_NVM_FW_ROOT);


