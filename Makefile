###########################################################
#
# Work in progress.
#
############################################################
ifneq ($(MAKECMDGOALS),docker)
ifneq ($(MAKECMDGOALS),docker-debug)

ifndef ONL
$(error Please source the setup.env script at the root of the ONL tree)
endif

include $(ONL)/make/config.mk

# All available architectures.
ALL_ARCHES := amd64 powerpc armel arm64 armhf

# Build rule for each architecture.
define build_arch_template
$(1) :
	$(MAKE) -C builds/$(1)
endef
$(foreach a,$(ALL_ARCHES),$(eval $(call build_arch_template,$(a))))


# Available build architectures based on the current suite
BUILD_ARCHES_wheezy := amd64 powerpc
BUILD_ARCHES_jessie := amd64 powerpc armel
BUILD_ARCHES_stretch := arm64 amd64 armel armhf

# Build available architectures by default.
.DEFAULT_GOAL := all
all: $(BUILD_ARCHES_$(ONL_DEBIAN_SUITE))


rebuild:
	$(ONLPM) --rebuild-pkg-cache


modclean:
	rm -rf $(ONL)/make/modules/modules.*

sdk_list := $(shell find $(ONLBASE)/packages/platforms-closed/platforms/pegatron -type d -name sdk)

distclean:
	@sudo git clean -dfx
	@for d in $(sdk_list); do					\
	    rm -fr $$d/builds/$(ONL_DEBIAN_SUITE);			\
	done
	@$(ONLBASE)/tools/cleanup-modules.sh
	@git reset --hard

endif
endif

.PHONY: docker

ifndef VERSION
VERSION := 8
endif

docker_check:
	@which docker > /dev/null || (echo "*** Docker appears to be missing. Please install docker.io in order to build OpenNetworkLinux." && exit 1)

docker: docker_check
	@OpenNetworkLinux/docker/tools/onlbuilder -$(VERSION) --isolate --hostname onlbuilder$(VERSION) --pull --autobuild --non-interactive

# create an interative docker shell, for debugging builds
docker-debug: docker_check
	@OpenNetworkLinux/docker/tools/onlbuilder -$(VERSION) --isolate --hostname onlbuilder$(VERSION) --pull


versions:
	$(ONL)/tools/make-versions.py --import-file=$(ONL)/tools/onlvi --class-name=OnlVersionImplementation --output-dir $(ONL)/make/versions --force

relclean:
	@find $(ONLBASE)/RELEASE -name "ONL-*" -delete
