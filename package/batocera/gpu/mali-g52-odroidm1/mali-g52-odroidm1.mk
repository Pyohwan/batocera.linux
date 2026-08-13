################################################################################
#
# mali-g52-odroidm1
#
################################################################################
# Track C: userspace blob is g29p1, the unified GLES+Vulkan build (DDK
# generation newer than g24p0, which A/B use) - gate 1 (2026-08-12) live-
# swapped just this file on an A image against our unchanged 6.1 kernel/
# kbase: no UK-ABI mismatch, GLES survived (ES System Info showed real
# GLSL ES 3.20/GL_VERSION strings), and vulkaninfo enumerated the GPU
# ("Mali-G52", DRIVER_ID_ARM_PROPRIETARY) - vendor g25p0 kbase accepts
# g29p1 userspace as-is, no out-of-tree kbase module needed (see
# project_odroid_retro_track_c_v3.md gate 1/light-path). Source:
# https://github.com/JeffyCN/mirrors, "libmali-next" branch (not "libmali"
# - g29p1 isn't published on the branch g24p0 used). Pinned to a specific
# commit rather than the branch HEAD for reproducible builds.
MALI_G52_ODROIDM1_G29P1_COMMIT = 4233031d818e97a19e8a9cdbbd5c15795ededd93
MALI_G52_ODROIDM1_G29P1_SOURCE = libmali-bifrost-g52-g29p1.so
MALI_G52_ODROIDM1_G29P1_SITE = https://raw.githubusercontent.com/JeffyCN/mirrors/$(MALI_G52_ODROIDM1_G29P1_COMMIT)/lib/aarch64-linux-gnu

# Peripheral files only (OpenCL vendor ICD JSON, profile.d, copyright) still
# come from the LinuxFactory g13p0 .deb - the actual libmali.so.1.9.0 binary
# extracted from it gets overwritten with the g29p1 blob above in
# EXTRACT_CMDS, same live-tested swap, just made to persist across rebuilds.
MALI_G52_ODROIDM1_VERSION = 1.9-5+202604211715~resolute
MALI_G52_ODROIDM1_SOURCE = libmali-bifrost-g52-g13p0-wayland-gbm_$(MALI_G52_ODROIDM1_VERSION)_arm64.deb
MALI_G52_ODROIDM1_SITE = https://ppa.linuxfactory.or.kr/pool/rockchip/libm/libmali
MALI_G52_ODROIDM1_LICENSE = Proprietary
MALI_G52_ODROIDM1_LICENSE_FILES = usr/share/doc/libmali-bifrost-g52-g13p0-wayland-gbm/copyright

MALI_G52_ODROIDM1_INSTALL_STAGING = YES
MALI_G52_ODROIDM1_PROVIDES = libegl libgbm libgles libmali
MALI_G52_ODROIDM1_DEPENDENCIES = libdrm wayland mesa3d-headers

# The .deb ships libraries only, no headers at all. The vendor libmali source
# tarball (same one mali-g31-gbm uses) ships its own KHR/EGL/GLES/GLES2/CL
# snapshot too, but it's dated 2022-03 (EGL_EGLEXT_VERSION 20190808) - wlroots
# and other modern consumers reject it as "too old". Use mesa3d-headers
# (current upstream Mesa release, selected below) for those instead, and only
# pull GBM/GLES3/FBDEV from the vendor tarball - the bits mesa3d-headers
# doesn't ship.
MALI_G52_ODROIDM1_HEADERS_VERSION = ad4c28932c3d07c75fc41dd4a3333f9013a25e7f
MALI_G52_ODROIDM1_EXTRA_DOWNLOADS = https://github.com/batocera-linux/rockchip-packages/releases/download/20220303/libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION).tar.gz
MALI_G52_ODROIDM1_EXTRA_DOWNLOADS += $(MALI_G52_ODROIDM1_G29P1_SITE)/$(MALI_G52_ODROIDM1_G29P1_SOURCE)

define MALI_G52_ODROIDM1_EXTRACT_CMDS
	$(AR) --output=$(@D) -x $(MALI_G52_ODROIDM1_DL_DIR)/$(MALI_G52_ODROIDM1_SOURCE)
	$(TAR) xf $(@D)/data.tar.gz -C $(@D)
	mkdir -p $(@D)/usr/include
	$(TAR) xf $(MALI_G52_ODROIDM1_DL_DIR)/libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION).tar.gz \
		--strip-components=2 -C $(@D)/usr/include \
		libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION)/include/GBM \
		libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION)/include/GLES3 \
		libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION)/include/FBDEV \
		libmali-$(MALI_G52_ODROIDM1_HEADERS_VERSION)/include/KHR/mali_khrplatform.h
	# The vendor GLES3/gl3platform.h does "#include <KHR/mali_khrplatform.h>"
	# instead of the standard "<KHR/khrplatform.h>" - it's the same Khronos
	# platform-typedefs content (same header guard, __khrplatform_h_), just
	# shipped under ARM's own filename. mesa3d-headers only installs the
	# standard-named khrplatform.h, so this vendor-named copy has to come
	# from here too, alongside it (no filename collision, both can coexist).
	# unlike EGL/GLES (meant to be #include <EGL/egl.h>), gbm.h is a top-level
	# header upstream (mesa installs it directly to $prefix/include/gbm.h) -
	# this vendor tarball nests it under GBM/ instead, which trips up cmake's
	# FindGBM (looks for $(includedir)/gbm.h, not $(includedir)/GBM/gbm.h)
	cp $(@D)/usr/include/GBM/gbm.h $(@D)/usr/include/gbm.h
	# The vendor tarball's GLES3 dir is missing gl3ext.h entirely (has
	# gl3.h/gl31.h/gl32.h/gl3platform.h only). Per upstream Khronos
	# convention this file is essentially a placeholder (GLES3 extensions
	# are declared in GLES2/gl2ext.h instead) - ship that standard content.
	cp $(MALI_G52_ODROIDM1_PKGDIR)/gl3ext.h $(@D)/usr/include/GLES3/gl3ext.h
	# Overwrite the g13p0 binary the .deb shipped with the g29p1 blob -
	# same filename (libmali.so.1.9.0), so every symlink/pkgconfig/
	# ld.so.preload path below still applies unchanged. Live-tested this
	# exact swap on real hardware first (see header comment).
	cp $(MALI_G52_ODROIDM1_DL_DIR)/$(MALI_G52_ODROIDM1_G29P1_SOURCE) \
		$(@D)/usr/lib/aarch64-linux-gnu/libmali.so.1.9.0
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
	# GLESv1/2, GBM - confirmed each with nm -D).
	#
	# wayland-egl is NOT in this list (was, up to track C): it doesn't
	# belong to the GPU driver at all - wl_egl_window_* is pure struct
	# bookkeeping (a malloc'd width/height/surface-pointer record the EGL
	# platform code reads directly), not a real driver entry point, so
	# it's the upstream wayland.org project's own reference impl that
	# ships it - and buildroot's plain "wayland" package already builds
	# and installs a real, working libwayland-egl.so.1 (confirmed via
	# nm -D: wl_egl_window_create/destroy/resize/get_attached_size all
	# present). g29p1 doesn't export any of these under either name
	# (confirmed via nm -D on the raw blob) - aliasing to libmali.so.1.9.0
	# like the others silently overwrote wayland's real implementation
	# with a broken one, only noticed once track C turned Wayland on and
	# something that actually creates an EGL window surface (kodi, then
	# libgtk3's Wayland GDK backend) tried to link against it.
	for lib in EGL:1 GLESv1_CM:1 GLESv2:2 MaliOpenCL:1 gbm:1; do \
		name=$${lib%%:*}; ver=$${lib##*:}; \
		ln -sf libmali.so.1.9.0 $(@D)/usr/lib/aarch64-linux-gnu/lib$${name}.so.$${ver}; \
		ln -sf lib$${name}.so.$${ver} $(@D)/usr/lib/aarch64-linux-gnu/lib$${name}.so; \
	done
endef

define MALI_G52_ODROIDM1_INSTALL_STAGING_CMDS
	mkdir -p $(STAGING_DIR)/usr/lib/pkgconfig
	cp -R $(@D)/usr/include/* $(STAGING_DIR)/usr/include/
	cp -R $(@D)/usr/lib/aarch64-linux-gnu/* $(STAGING_DIR)/usr/lib/
	# This target has no X11 (no XWayland), but eglplatform.h's generic
	# "#elif defined(__unix__)" fallback assumes X11 unless steered to
	# its earlier Wayland/GBM-safe branch via this define. mesa3d-headers
	# (our EGL header source, see DEPENDENCIES) ships the same upstream
	# eglplatform.h logic, so patch its staged copy the same way.
	grep -q MESA_EGL_NO_X11_HEADERS $(STAGING_DIR)/usr/include/EGL/eglplatform.h || \
		sed -i '1a #define MESA_EGL_NO_X11_HEADERS 1' $(STAGING_DIR)/usr/include/EGL/eglplatform.h
	# This vendor gbm.h never declares gbm_bo_get_fd_for_plane, the name
	# upstream Mesa standardized on and wlroots >= 0.18 actually calls -
	# g13p0-era blobs only exported the pre-standardization name
	# (gbm_bo_get_fd_per_plane) under the hood, so this used to always
	# inject a declare-and-alias-the-old-name macro. g24p0's
	# libmali.so.1.9.0 has since started exporting gbm_bo_get_fd_for_plane
	# directly (confirmed via nm -D) - the vendor's header text just never
	# caught up - so aliasing to per_plane unconditionally now points at a
	# symbol that no longer exists in the .so, breaking the link instead of
	# fixing it (invisible until wlroots, the first real caller of this
	# symbol on this board, failed with "undefined reference to
	# gbm_bo_get_fd_per_plane"). Check the actual exported symbol table so
	# this keeps working across blob versions either way: alias only if the
	# .so genuinely lacks the modern name, otherwise just declare it (the
	# .so already has it, only the header prototype is missing).
	# Insert right before the closing "#ifdef __cplusplus / }" block (the
	# second occurrence) so it stays inside both extern "C" and the
	# include guard, instead of a blind end-of-file append.
	if ! grep -q gbm_bo_get_fd_for_plane $(STAGING_DIR)/usr/include/gbm.h; then \
		if nm -D $(STAGING_DIR)/usr/lib/libmali.so.1.9.0 | grep -q ' T gbm_bo_get_fd_for_plane$$'; then \
			DECL='int\ngbm_bo_get_fd_for_plane(struct gbm_bo *bo, int plane);\n\n'; \
		else \
			DECL='int\ngbm_bo_get_fd_per_plane(struct gbm_bo *bo, int plane);\n#define gbm_bo_get_fd_for_plane gbm_bo_get_fd_per_plane\n\n'; \
		fi; \
		LINE=$$(grep -n '^#ifdef __cplusplus' $(STAGING_DIR)/usr/include/gbm.h | tail -1 | cut -d: -f1); \
		head -n $$((LINE-1)) $(STAGING_DIR)/usr/include/gbm.h > $(STAGING_DIR)/usr/include/gbm.h.new; \
		printf "$$DECL" >> $(STAGING_DIR)/usr/include/gbm.h.new; \
		tail -n +$$LINE $(STAGING_DIR)/usr/include/gbm.h >> $(STAGING_DIR)/usr/include/gbm.h.new; \
		mv $(STAGING_DIR)/usr/include/gbm.h.new $(STAGING_DIR)/usr/include/gbm.h; \
	fi
	$(INSTALL) -D -m 0644 $(MALI_G52_ODROIDM1_PKGDIR)/egl.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/egl.pc
	$(INSTALL) -D -m 0644 $(MALI_G52_ODROIDM1_PKGDIR)/glesv2.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/glesv2.pc
	$(INSTALL) -D -m 0644 $(MALI_G52_ODROIDM1_PKGDIR)/gbm.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/gbm.pc
endef

define MALI_G52_ODROIDM1_INSTALL_TARGET_CMDS
	# not etc/ld.so.conf.d/00-aarch64-mali.conf: buildroot's target-finalize
	# forbids that directory entirely (it bakes lib search paths into the
	# toolchain instead of relying on runtime ldconfig), and we don't need
	# it anyway - it only registers usr/lib/aarch64-linux-gnu/mali, the
	# near-empty shim directory we never link against (see EXTRACT_CMDS).
	mkdir -p $(TARGET_DIR)/etc/OpenCL/vendors $(TARGET_DIR)/etc/profile.d
	cp -R $(@D)/etc/OpenCL/vendors/* $(TARGET_DIR)/etc/OpenCL/vendors/
	cp -R $(@D)/etc/profile.d/* $(TARGET_DIR)/etc/profile.d/
	cp -R $(@D)/usr/lib/aarch64-linux-gnu/* $(TARGET_DIR)/usr/lib/
	# Without this, any normally-linked consumer (confirmed with wlroots/
	# labwc) intermittently fails at its first EGL call with "symbol
	# lookup error: undefined symbol: eglQueryString" even though the
	# symbol is genuinely exported (checked with nm -D/objdump -T,
	# correctly-versioned, no duplicate libmali.so.1 elsewhere) - a lazy
	# PLT-binding/symbol-visibility quirk specific to this vendor blob's
	# huge, non-standard-toolchain-built export table. Forcing it into
	# every process's global scope via ld.so.preload (confirmed fix,
	# tested live via LD_PRELOAD) sidesteps whatever the exact defect is.
	echo "/usr/lib/libmali.so.1.9.0" >> $(TARGET_DIR)/etc/ld.so.preload
endef

$(eval $(generic-package))
