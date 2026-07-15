DKMS_NAME ?= r8152
DKMS_VERSION ?= 2.22.1
DKMS_SOURCE_DIR ?= /usr/src/$(DKMS_NAME)-$(DKMS_VERSION)
DKMS_SOURCE_FILES := r8152.c compatibility.h Makefile dkms.conf \
	50-usb-realtek-net.rules LICENSE README.md README.zh.md
RULEFILE ?= 50-usb-realtek-net.rules
RULEDIR ?= $(DESTDIR)/etc/udev/rules.d

ifneq ($(KERNELRELEASE),)
	obj-m	 := r8152.o
#	ccflags-y += -DRTL8152_DEBUG

	ifeq (TRUE, $(shell test $(VERSION) -lt 5 && echo "TRUE" || \
		test $(VERSION) -eq 5 && test $(PATCHLEVEL) -lt 12 && echo "TRUE"))
		ccflags-y += -DLINUX_VERSION_MAJOR=$(VERSION)
		ccflags-y += -DLINUX_VERSION_PATCHLEVEL=$(PATCHLEVEL)
		ccflags-y += -DLINUX_VERSION_SUBLEVEL=$(SUBLEVEL)
	endif
else
	KERNELDIR ?= /lib/modules/$(shell uname -r)/build
	PWD :=$(shell pwd)
	TARGET_PATH := kernel/drivers/net/usb

.PHONY: modules all clean install install_rules uninstall_rules \
	dkms-source dkms-add dkms-build dkms-install dkms-uninstall

modules:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules

all: clean modules install

clean:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) clean

install:
ifneq ($(shell lsmod | grep r8153_ecm),)
	rmmod r8153_ecm
endif
ifneq ($(shell lsmod | grep r8152),)
	rmmod r8152
endif
	if [ -d "$(subst build,$(TARGET_PATH),$(KERNELDIR))" ]; then \
		find "$(subst build,$(TARGET_PATH),$(KERNELDIR))" \
			-name 'r8152.ko.*' -type f -exec rm -f {} +; \
	fi
	$(MAKE) -C $(KERNELDIR) M=$(PWD) INSTALL_MOD_DIR=$(TARGET_PATH) modules_install
	$(MAKE) install_rules
	modprobe r8152

install_rules:
	install -d -m 0755 "$(RULEDIR)"
	install -m 0644 "$(RULEFILE)" "$(RULEDIR)/$(RULEFILE)"

uninstall_rules:
	rm -f "$(RULEDIR)/$(RULEFILE)"

dkms-source:
	install -d -m 0755 "$(DKMS_SOURCE_DIR)"
	install -m 0644 $(DKMS_SOURCE_FILES) "$(DKMS_SOURCE_DIR)"
	install -m 0755 dkms-install-rules "$(DKMS_SOURCE_DIR)"

dkms-add: dkms-source
	dkms add -m "$(DKMS_NAME)" -v "$(DKMS_VERSION)"

dkms-build: dkms-add
	dkms build -m "$(DKMS_NAME)" -v "$(DKMS_VERSION)"

dkms-install: dkms-build
	dkms install -m "$(DKMS_NAME)" -v "$(DKMS_VERSION)"

dkms-uninstall:
	dkms remove -m "$(DKMS_NAME)" -v "$(DKMS_VERSION)" --all
	$(MAKE) uninstall_rules
	for file in $(DKMS_SOURCE_FILES) dkms-install-rules; do \
		rm -f "$(DKMS_SOURCE_DIR)/$$file"; \
	done
	rmdir "$(DKMS_SOURCE_DIR)"

endif
