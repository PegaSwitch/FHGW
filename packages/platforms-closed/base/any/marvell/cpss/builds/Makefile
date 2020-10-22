include $(ONL)/make/config.mk

ifndef CPSS_BUILD_DIR
$(error $$CPSS_BUILD_DIR must be set)
endif

export CPSS_TARGET_DIR := $(CPSS_BUILD_DIR)/$(ONL_DEBIAN_SUITE)

ifndef CPSS
$(error $$CPSS must be set)
endif

ifndef KERNEL
$(error $$KERNELS must be set)
endif

KERNEL_LTS_VERSION := $(patsubst onl-kernel-%-x86-64-all:amd64,%,$(KERNEL))

ifndef ARCH
$(error $$ARCH must be set)
endif

sdk:
	$(MAKE) -C $(ONLBASE)/packages/platforms-closed/base/any/marvell/$(CPSS)/configs/$(subst _,-,$(ARCH))/$(KERNEL_LTS_VERSION) KERNEL=$(KERNEL) CPSS=$(CPSS) $(ONL_MAKE_PARALLEL)

clean:

setup::
