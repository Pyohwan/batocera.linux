################################################################################
#
# mali-g52-odroidm1
#
################################################################################
# Prebuilt Mali-G52 userspace blob matching the g13p0 in-kernel DDK used by
# the hardkernel BSP kernel on ODROID-M1 (RK3568). Same package/version
# verified installed on the real device's official Ubuntu 26.04 image
# (dpkg: libmali-bifrost-g52-g13p0-wayland-gbm 5:1.9-5+202604211715~resolute).
# Distributed by LinuxFactory, hardkernel's official RK3568 BSP package repo.

MALI_G52_ODROIDM1_VERSION = 1.9-5+202604211715~resolute
MALI_G52_ODROIDM1_SOURCE = libmali-bifrost-g52-g13p0-wayland-gbm_$(MALI_G52_ODROIDM1_VERSION)_arm64.deb
MALI_G52_ODROIDM1_SITE = https://ppa.linuxfactory.or.kr/pool/rockchip/libm/libmali
MALI_G52_ODROIDM1_LICENSE = Proprietary
MALI_G52_ODROIDM1_LICENSE_FILES = usr/share/doc/libmali-bifrost-g52-g13p0-wayland-gbm/copyright

MALI_G52_ODROIDM1_INSTALL_STAGING = YES
MALI_G52_ODROIDM1_PROVIDES = libegl libgbm libgles libmali
MALI_G52_ODROIDM1_DEPENDENCIES = libdrm wayland

define MALI_G52_ODROIDM1_EXTRACT_CMDS
	$(AR) --output=$(@D) -x $(MALI_G52_ODROIDM1_DL_DIR)/$(MALI_G52_ODROIDM1_SOURCE)
	$(TAR) xf $(@D)/data.tar.gz -C $(@D)
endef

define MALI_G52_ODROIDM1_INSTALL_STAGING_CMDS
	mkdir -p $(STAGING_DIR)/usr/lib/pkgconfig
	cp -R $(@D)/usr/lib/aarch64-linux-gnu/* $(STAGING_DIR)/usr/lib/
endef

define MALI_G52_ODROIDM1_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/etc/ld.so.conf.d $(TARGET_DIR)/etc/OpenCL/vendors
	cp -R $(@D)/etc/* $(TARGET_DIR)/etc/
	cp -R $(@D)/usr/lib/aarch64-linux-gnu/* $(TARGET_DIR)/usr/lib/
endef

$(eval $(generic-package))
