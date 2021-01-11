CPSS_ROOT	= cpss/compilation_root
CPSS_VER	= cpss_4.2/ia64_DX
CPSS_FILES	= appDemo appDemo.map version_info.c
BASE_DIR	= $(ONLBASE)/packages/platforms-closed/platforms/pegatron/FHGW
SDK_BASE_DIR	= $(BASE_DIR)/sdk/builds


all:
	mkdir -p $(ONL_DEBIAN_SUITE)/$(CPSS_ROOT)
	for f in $(CPSS_FILES); do					\
	    cp $(SDK_BASE_DIR)/$(ONL_DEBIAN_SUITE)/$(CPSS_ROOT)/$(CPSS_VER)/$$f $(ONL_DEBIAN_SUITE)/$(CPSS_ROOT);						\
	done


