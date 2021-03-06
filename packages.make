# -*- mode: makefile -*-
#
# This Makefile is copied by repo to the top of the sandbox
#

include tools/packages/versions.mk

#
# KVERS
#    The kernel version to use when building a kernel module.
KVERS ?= `uname -r`

#
# KEYID
#    Specify secret key id when generating source packages.
#
KEYID?=
KEYOPT=-k$(KEYID)

#
# Directories listed in manifest (excluding package scripts)
#
SOURCE_CONTRAIL_ARCHIVE:=SConstruct SConstruct tools/build tools/packages/utils controller vrouter third_party tools/generateds tools/sandesh openstack/nova_contrail_vif openstack/neutron_plugin openstack/nova_extensions openstack/contrail-heat contrail-webui-third-party
SERIES=$(shell lsb_release -c -s)

# DPDK vRouter is currently supported only on Ubuntu 12.04 Precise and 14.04 Trusty
ifeq ($(SERIES),precise)
    CONTRAIL_VROUTER_DPDK := package-contrail-vrouter-dpdk
endif
ifeq ($(SERIES),trusty)
    CONTRAIL_VROUTER_DPDK := package-contrail-vrouter-dpdk
endif
ifeq ($(SERIES),xenial)
    CONTRAIL_VROUTER_DPDK := package-contrail-vrouter-dpdk
endif

source-all: source-package-contrail-web-core \
	source-package-contrail-web-controller \
	source-package-contrail \
	source-package-ifmap-server \
	source-package-neutron-plugin-contrail \
	source-package-ceilometer-plugin-contrail \
	source-package-contrail-heat
	source-$(CONTRAIL_VROUTER_DPDK)

all: package-ifmap-server \
	package-contrail-web-core \
	package-contrail-web-controller \
	package-contrail \
	package-neutron-plugin-contrail \
	package-ceilometer-plugin-contrail \
	package-contrail-heat \
	$(CONTRAIL_VROUTER_DPDK)

package-ifmap-server: clean-ifmap-server debian-ifmap-server
	$(eval PACKAGE := $(patsubst package-%,%,$@))
	@echo "Building package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); fakeroot debian/rules get-orig-source)
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -uc -us -b -rfakeroot)

fetch-webui-third-party:
	@echo "Fetching webui third party"
	(cd contrail-webui-third-party; python fetch_packages.py -f packages.xml)
	rm -rf contrail-web-core/node_modules
	mkdir contrail-web-core/node_modules
	cp -rf contrail-webui-third-party/node_modules/* contrail-web-core/node_modules/

package-contrail-web-core: clean-contrail-web-core debian-contrail-web-core fetch-webui-third-party
	$(eval PACKAGE := $(patsubst package-%,%,$@))
	@echo "Building package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); sed -i 's/VERSION/$(WEBUI_CORE_VERSION)/g' debian/changelog)
	(cd build/packages/$(PACKAGE); sed -i 's/SERIES/$(SERIES)/g' debian/changelog)
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -j$(JOBS) -uc -us -b -rfakeroot)

source-package-contrail-web-core: clean-contrail-web-core debian-contrail-web-core fetch-webui-third-party
	$(eval PACKAGE := $(patsubst source-package-%,%,$@))
	@echo "Building source package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); sed -i 's/VERSION/$(WEBUI_CORE_VERSION)/g' debian/changelog)
	(cd build/packages/$(PACKAGE); sed -i 's/SERIES/$(SERIES)/g' debian/changelog)
	tar zcf build/packages/$(PACKAGE)_$(WEBUI_CORE_VERSION).orig.tar.gz contrail-web-core contrail-webui-third-party
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -j$(JOBS) -S -d -rfakeroot $(KEYOPT))

source-contrail-web-controller: fetch-webui-third-party
	$(eval PACKAGE := $(patsubst source-%,%,$@))
	tar zcf build/packages/$(PACKAGE)_$(WEBUI_CONTROLLER_VERSION).orig.tar.gz contrail-web-controller contrail-web-core contrail-webui-third-party

package-contrail-web-controller: clean-contrail-web-controller debian-contrail-web-controller source-contrail-web-controller
	$(eval PACKAGE := $(patsubst package-%,%,$@))
	@echo "Building package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); sed -i 's/VERSION/$(WEBUI_CONTROLLER_VERSION)/g' debian/changelog)
	(cd build/packages/$(PACKAGE); sed -i 's/SERIES/$(SERIES)/g' debian/changelog)
	tar xzf build/packages/$(PACKAGE)_$(WEBUI_CONTROLLER_VERSION).orig.tar.gz -C build/packages/$(PACKAGE)/
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -j$(JOBS) -uc -us -b -rfakeroot)

source-package-contrail-web-controller: clean-contrail-web-controller debian-contrail-web-controller source-contrail-web-controller
	$(eval PACKAGE := $(patsubst source-package-%,%,$@))
	@echo "Building source package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); sed -i 's/VERSION/$(WEBUI_CONTROLLER_VERSION)/g' debian/changelog)
	(cd build/packages/$(PACKAGE); sed -i 's/SERIES/$(SERIES)/g' debian/changelog)
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -j$(JOBS) -S -d -rfakeroot $(KEYOPT))

package-contrail: debian-contrail
	$(eval PACKAGE := contrail)
	@echo "Building package $(PACKAGE)"
	sed -i 's/VERSION/$(CONTRAIL_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	# Append series specific build depends
	(cd build/packages/$(PACKAGE)/debian; sed -i '/BUILDDEP_SERIES/r builddep.$(SERIES)' control)
	sed -i '/BUILDDEP_SERIES/d' build/packages/$(PACKAGE)/debian/control
	# Append series specific depends
	(cd build/packages/$(PACKAGE)/debian; sed -i '/SUPERVISORDEP_SERIES/r supervisordep.$(SERIES)' control)
	sed -i '/SUPERVISORDEP_SERIES/d' build/packages/$(PACKAGE)/debian/control
	(cd build/packages/$(PACKAGE)/debian; sed -i '/NODEMGRDEP_SERIES/r nodemgrdep.$(SERIES)' control)
	sed -i '/NODEMGRDEP_SERIES/d' build/packages/$(PACKAGE)/debian/control
	# Append series specific install files
	$(eval CONTRAIL_INSTALL_SERIES := $(shell cd build/packages/$(PACKAGE)/debian; find . -name '*.install.$(SERIES)'))
	$(foreach series_fname, $(CONTRAIL_INSTALL_SERIES), \
			(cd build/packages/$(PACKAGE)/debian;\
			sed -i '/INSTALL_SERIES/r $(series_fname)' $(patsubst %.$(SERIES),%,$(series_fname))); )
	$(eval CONTRAIL_INSTALL := $(shell cd build/packages/$(PACKAGE)/debian; find . -name '*.install'))
	$(foreach install_fname, $(CONTRAIL_INSTALL), \
			(cd build/packages/$(PACKAGE)/debian;\
			sed -i '/INSTALL_SERIES/d' $(install_fname)); )
	# Append series specific dirs
	$(eval CONTRAIL_DIRS_SERIES := $(shell cd build/packages/$(PACKAGE)/debian; find . -name '*.dirs.$(SERIES)'))
	$(foreach series_dirname, $(CONTRAIL_DIRS_SERIES), \
			(cd build/packages/$(PACKAGE)/debian;\
			sed -i '/DIRS_SERIES/r $(series_dirname)' $(patsubst %.$(SERIES),%,$(series_dirname))); )
	$(eval CONTRAIL_DIRS := $(shell cd build/packages/$(PACKAGE)/debian; find . -name '*.dirs'))
	$(foreach dir_fname, $(CONTRAIL_DIRS), \
			(cd build/packages/$(PACKAGE)/debian;\
			sed -i '/DIRS_SERIES/d' $(dir_fname)); )
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -uc -us -b -rfakeroot)
	chmod u+x build/packages/contrail/debian/rules.modules
	(cd build/packages/$(PACKAGE); fakeroot debian/rules.modules KVERS=$(KVERS) binary-modules)

source-package-contrail: clean-contrail debian-contrail
	$(eval PACKAGE := contrail)
	sed -i 's/VERSION/$(CONTRAIL_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	# Append series specific build depends
	(cd build/packages/$(PACKAGE)/debian; sed -i '/BUILDDEP_SERIES/r builddep.$(SERIES)' control)
	sed -i '/BUILDDEP_SERIES/d' build/packages/$(PACKAGE)/debian/control
	# Append series specific depends
	(cd build/packages/$(PACKAGE)/debian; sed -i '/SUPERVISORDEP_SERIES/r supervisordep.$(SERIES)' control)
	sed -i '/SUPERVISORDEP_SERIES/d' build/packages/$(PACKAGE)/debian/control
	(cd build/packages/$(PACKAGE)/debian; sed -i '/NODEMGRDEP_SERIES/r builddep.$(SERIES)' control)
	sed -i '/NODEMGRDEP_SERIES/d' build/packages/$(PACKAGE)/debian/control
	# Append series specific install files
	$(eval CONTRAIL_INSTALL_SERIES := $(shell cd build/packages/$(PACKAGE)/debian; find . -name '*.install.$(SERIES)'))
	$(foreach series_fname, $(CONTRAIL_INSTALL_SERIES), \
			(cd build/packages/$(PACKAGE)/debian;\
			sed -i '/INSTALL_SERIES/r $(series_fname)' $(patsubst %.$(SERIES),%,$(series_fname))); )
	$(eval CONTRAIL_INSTALL := $(shell cd build/packages/$(PACKAGE)/debian; find . -name '*.install'))
	$(foreach install_fname, $(CONTRAIL_INSTALL), \
			(cd build/packages/$(PACKAGE)/debian;\
			sed -i '/INSTALL_SERIES/d' $(install_fname)); )
	# Append series specific dirs
	$(eval CONTRAIL_DIRS_SERIES := $(shell cd build/packages/$(PACKAGE)/debian; find . -name '*.dirs.$(SERIES)'))
	$(foreach series_dirname, $(CONTRAIL_DIRS_SERIES), \
			(cd build/packages/$(PACKAGE)/debian;\
			sed -i '/DIRS_SERIES/r $(series_dirname)' $(patsubst %.$(SERIES),%,$(series_dirname))); )
	$(eval CONTRAIL_DIRS := $(shell cd build/packages/$(PACKAGE)/debian; find . -name '*.dirs'))
	$(foreach dir_fname, $(CONTRAIL_DIRS), \
			(cd build/packages/$(PACKAGE)/debian;\
			sed -i '/DIRS_SERIES/d' $(dir_fname)); )
	(cd vrouter; git clean -f -d)
	tar zcf build/packages/contrail_$(CONTRAIL_VERSION).orig.tar.gz $(SOURCE_CONTRAIL_ARCHIVE)
	@echo "Building source package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -S -d -rfakeroot $(KEYOPT))

source-package-contrail-vrouter-dpdk: clean-contrail-vrouter-dpdk debian-contrail-vrouter-dpdk
	$(eval PACKAGE := contrail-vrouter-dpdk)
	sed -i 's/VERSION/$(CONTRAIL_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	(cd build/packages/$(PACKAGE)/debian; sed -i '/BUILDDEP_SERIES/r builddep.$(SERIES)' control)
	sed -i '/BUILDDEP_SERIES/d' build/packages/$(PACKAGE)/debian/control
	tar zcf build/packages/$(PACKAGE)_$(CONTRAIL_VERSION).orig.tar.gz $(SOURCE_CONTRAIL_ARCHIVE)
	@echo "Building source package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -S -d -rfakeroot $(KEYOPT))

source-ifmap-server:
	$(eval PACKAGE := ifmap-server)
	(cd build/packages/$(PACKAGE); fakeroot debian/rules get-orig-source)

source-package-ifmap-server: clean-ifmap-server debian-ifmap-server source-ifmap-server
	$(eval PACKAGE := ifmap-server)
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -S -d -rfakeroot $(KEYOPT))

package-neutron-plugin-contrail: debian-neutron-plugin-contrail
	$(eval PACKAGE = neutron-plugin-contrail)
	cp -R openstack/neutron_plugin/* build/packages/neutron-plugin-contrail
	sed -i 's/VERSION/$(NEUTRON_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	@echo "Building package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -uc -us -b -rfakeroot)

source-package-neutron-plugin-contrail: clean-neutron-plugin-contrail debian-neutron-plugin-contrail source-neutron-plugin-contrail
	$(eval PACKAGE = neutron-plugin-contrail)
	cp -R openstack/neutron_plugin/* build/packages/neutron-plugin-contrail
	sed -i 's/VERSION/$(NEUTRON_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	@echo "Building source package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -S -d -rfakeroot $(KEYOPT))

source-neutron-plugin-contrail: build/packages/neutron-plugin-contrail_$(NEUTRON_VERSION).orig.tar.gz
build/packages/neutron-plugin-contrail_$(NEUTRON_VERSION).orig.tar.gz:
	(cd openstack/neutron_plugin && tar zcvf ../../build/packages/neutron-plugin-contrail_$(NEUTRON_VERSION).orig.tar.gz .)

package-ceilometer-plugin-contrail: debian-ceilometer-plugin-contrail
	$(eval PACKAGE = ceilometer-plugin-contrail)
	cp -R openstack/ceilometer_plugin/* build/packages/ceilometer-plugin-contrail
	sed -i 's/VERSION/$(CEILOMETER_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	@echo "Building package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -uc -us -b -rfakeroot)

source-package-ceilometer-plugin-contrail: clean-ceilometer-plugin-contrail debian-ceilometer-plugin-contrail source-ceilometer-plugin-contrail
	$(eval PACKAGE = ceilometer-plugin-contrail)
	cp -R openstack/ceilometer_plugin/* build/packages/ceilometer-plugin-contrail
	sed -i 's/VERSION/$(CEILOMETER_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	@echo "Building source package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -S -d -rfakeroot $(KEYOPT))

source-ceilometer-plugin-contrail: build/packages/ceilometer-plugin-contrail_$(CEILOMETER_VERSION).orig.tar.gz
build/packages/ceilometer-plugin-contrail_$(CEILOMETER_VERSION).orig.tar.gz:
	(cd openstack/ceilometer_plugin && tar zcvf ../../build/packages/ceilometer-plugin-contrail_$(CEILOMETER_VERSION).orig.tar.gz .)

package-contrail-heat: debian-contrail-heat
	$(eval PACKAGE = contrail-heat)
	cp -R openstack/contrail-heat/* build/packages/contrail-heat
	sed -i 's/VERSION/$(CONTRAIL_HEAT_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	@echo "Building package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -uc -us -b -rfakeroot)

source-package-contrail-heat: clean-contrail-heat debian-contrail-heat source-contrail-heat
	$(eval PACKAGE = contrail-heat)
	cp -R openstack/contrail-heat/* build/packages/contrail-heat
	sed -i 's/VERSION/$(CONTRAIL_HEAT_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	@echo "Building source package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -S -d -rfakeroot $(KEYOPT))

source-contrail-heat: build/packages/contrail-heat_$(CONTRAIL_HEAT_VERSION).orig.tar.gz
build/packages/contrail-heat_$(CONTRAIL_HEAT_VERSION).orig.tar.gz:
	(cd openstack/contrail-heat && tar zcvf ../../build/packages/contrail-heat_$(CONTRAIL_HEAT_VERSION).orig.tar.gz .)

package-contrail-vrouter-dpdk: debian-contrail-vrouter-dpdk
	$(eval PACKAGE := contrail-vrouter-dpdk)
	@echo "Building package $(PACKAGE)"
	sed -i 's/VERSION/$(CONTRAIL_VERSION)/g' build/packages/$(PACKAGE)/debian/changelog
	sed -i 's/SERIES/$(SERIES)/g' build/packages/$(PACKAGE)/debian/changelog
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -uc -us -b -rfakeroot)

package-%: debian-%
	$(eval PACKAGE := $(patsubst package-%,%,$@))
	@echo "Building package $(PACKAGE)"
	(cd build/packages/$(PACKAGE); dpkg-buildpackage -uc -us -b -rfakeroot)

debian-%:
	$(eval PACKAGE := $(patsubst debian-%,%,$@))
	mkdir -p build/packages/$(PACKAGE)
	cp -R tools/packages/debian/$(PACKAGE)/debian build/packages/$(PACKAGE)
	cp -R tools/packages/utils build/packages/$(PACKAGE)/debian/
	chmod u+x build/packages/$(PACKAGE)/debian/rules

clean-%:
	$(eval PACKAGE := $(patsubst clean-%,%,$@))
	rm -rf build/packages/$(PACKAGE)
