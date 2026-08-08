################################################################################
#
# melonds
#
################################################################################

MELONDS_VERSION = 1.1
MELONDS_SITE = https://github.com/Arisotura/melonDS.git
MELONDS_SITE_METHOD=git
MELONDS_GIT_SUBMODULES=YES
MELONDS_LICENSE = GPLv2
MELONDS_EMULATOR_INFO = melonds.emulator.yml
MELONDS_DEPENDENCIES += ecm sdl2 slirp libepoxy libarchive libenet
MELONDS_DEPENDENCIES += qt6base qt6svg qt6multimedia

# X11 is find_package(X11 REQUIRED) unconditionally on Linux in melonDS's own
# CMakeLists.txt, even though this board runs neither X11 nor Wayland at
# runtime (see ENABLE_WAYLAND note below) - it's only linked against, never
# actually used.
ifeq ($(BR2_PACKAGE_MALI_G52_ODROIDM1),y)
MELONDS_DEPENDENCIES += xlib_libX11 libinput
endif

MELONDS_SUPPORTS_IN_SOURCE_BUILD = NO

MELONDS_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
MELONDS_CONF_OPTS += -DCMAKE_INSTALL_PREFIX="/usr"
MELONDS_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
MELONDS_CONF_OPTS += -DUSE_QT6=ON

# wayland is currently broken, don't set this. This board (odroid-m1) was
# briefly special-cased to ON here on the assumption that Wayland was the
# only option since it has no XWayland - live-tested and wrong: the vendor
# Mali blob's Wayland-*client* EGL platform is itself broken on this board
# (eglGetPlatformDisplayEXT succeeds, eglInitialize always fails with
# EGL_NOT_INITIALIZED - confirmed on both g13p0 and g24p0 blob versions,
# see board defconfig comment / Joplin "GPU 렌더링 경로" note), unrelated to
# desktop GL availability. The actual working path on this board is Qt's
# "eglfs" platform plugin (direct KMS/GBM, same EGL platform every other
# consumer on this board already uses successfully) via QT_QPA_PLATFORM=
# eglfs at runtime - which needs libinput (added above) for its KMS input
# backend, nothing Wayland-related at all.
MELONDS_CONF_OPTS += -DENABLE_WAYLAND=OFF

define MELONDS_INSTALL_TARGET_CMDS
    $(INSTALL) -D $(@D)/buildroot-build/melonDS \
		$(TARGET_DIR)/usr/bin/
endef

$(eval $(cmake-package))
$(eval $(emulator-info-package))
