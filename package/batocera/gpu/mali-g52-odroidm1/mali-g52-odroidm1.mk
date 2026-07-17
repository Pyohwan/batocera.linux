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

# The .deb ships libraries only, no KHR/EGL/GLES/GBM headers. Pull them from
# the same libmali source tarball mali-g31-gbm already uses in this tree
# (rockchip-linux/libmali, mirrored by batocera-linux) - just the headers,
# not building the whole thing from source.
MALI_G52_ODROIDM1_HEADERS_VERSION = ad4c28932c3d07c75fc41dd4a3333f9013a25e7f
MALI_G52_ODROIDM1_EXTRA_DOWNLOADS = https://github.com/batocera-linux/rockchip-packages/releases/download/20220303/libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION).tar.gz

define MALI_G52_ODROIDM1_EXTRACT_CMDS
	$(AR) --output=$(@D) -x $(MALI_G52_ODROIDM1_DL_DIR)/$(MALI_G52_ODROIDM1_SOURCE)
	$(TAR) xf $(@D)/data.tar.gz -C $(@D)
	mkdir -p $(@D)/usr/include
	$(TAR) xf $(MALI_G52_ODROIDM1_DL_DIR)/libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION).tar.gz \
		--strip-components=2 -C $(@D)/usr/include \
		libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION)/include
	# matches upstream's own meson.build: KHR/mali_khrplatform.h installs as khrplatform.h
	cp $(@D)/usr/include/KHR/mali_khrplatform.h $(@D)/usr/include/KHR/khrplatform.h
	# unlike EGL/GLES (meant to be #include <EGL/egl.h>), gbm.h is a top-level
	# header upstream (mesa installs it directly to $prefix/include/gbm.h) -
	# this vendor tarball nests it under GBM/ instead, which trips up cmake's
	# FindGBM (looks for $(includedir)/gbm.h, not $(includedir)/GBM/gbm.h)
	cp $(@D)/usr/include/GBM/gbm.h $(@D)/usr/include/gbm.h
	# This target has no X11 (no XWayland), but eglplatform.h's generic
	# "#elif defined(__unix__)" fallback assumes X11 unless steered to
	# its earlier Wayland/GBM-safe branch via this define.
	sed -i '1a #define MESA_EGL_NO_X11_HEADERS 1' $(@D)/usr/include/EGL/eglplatform.h
	# On a real dpkg system these top-level sonames get created by
	# update-alternatives at install time (nothing in this .deb's own
	# postinst does it - it only ships a reboot notice). Since we're
	# not running dpkg, recreate them ourselves so find_library() and
	# normal linking can find EGL/GLESv1/GLESv2/gbm/wayland-egl at the
	# standard path.
	#
	# Point them at libmali.so.1.9.0 itself, not mali/libEGL.so.1 etc:
	# those per-API files under mali/ are near-empty shims (checked
	# with nm -D: 4 boilerplate symbols, no eglGetProcAddress or
	# anything else) meant to be fixed up at runtime by libmali-hook /
	# mali-priority.sh: not something a static link at build time can
	# rely on. libmali.so.1.9.0 exports every symbol directly (EGL,
	# GLESv1/2, GBM, wayland-egl - confirmed each with nm -D).
	for lib in EGL:1 GLESv1_CM:1 GLESv2:2 MaliOpenCL:1 gbm:1 wayland-egl:1; do \
		name=$${lib%%:*}; ver=$${lib##*:}; \
		ln -sf libmali.so.1.9.0 $(@D)/usr/lib/aarch64-linux-gnu/lib$${name}.so.$${ver}; \
		ln -sf lib$${name}.so.$${ver} $(@D)/usr/lib/aarch64-linux-gnu/lib$${name}.so; \
	done
endef

define MALI_G52_ODROIDM1_INSTALL_STAGING_CMDS
	mkdir -p $(STAGING_DIR)/usr/lib/pkgconfig
	cp -R $(@D)/usr/include/* $(STAGING_DIR)/usr/include/
	cp -R $(@D)/usr/lib/aarch64-linux-gnu/* $(STAGING_DIR)/usr/lib/
	$(INSTALL) -D -m 0644 $(MALI_G52_ODROIDM1_PKGDIR)/egl.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/egl.pc
	$(INSTALL) -D -m 0644 $(MALI_G52_ODROIDM1_PKGDIR)/glesv2.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/glesv2.pc
	$(INSTALL) -D -m 0644 $(MALI_G52_ODROIDM1_PKGDIR)/gbm.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/gbm.pc
endef

define MALI_G52_ODROIDM1_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/etc/ld.so.conf.d $(TARGET_DIR)/etc/OpenCL/vendors
	cp -R $(@D)/etc/* $(TARGET_DIR)/etc/
	cp -R $(@D)/usr/lib/aarch64-linux-gnu/* $(TARGET_DIR)/usr/lib/
endef

$(eval $(generic-package))
