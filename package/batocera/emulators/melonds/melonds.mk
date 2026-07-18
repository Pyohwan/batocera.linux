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
# CMakeLists.txt, even when building with ENABLE_WAYLAND=ON below - it's only
# linked against, not actually used at runtime on a real Wayland session.
ifeq ($(BR2_PACKAGE_MALI_G52_ODROIDM1),y)
MELONDS_DEPENDENCIES += xlib_libX11 qt6wayland
endif

MELONDS_SUPPORTS_IN_SOURCE_BUILD = NO

MELONDS_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
MELONDS_CONF_OPTS += -DCMAKE_INSTALL_PREFIX="/usr"
MELONDS_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
MELONDS_CONF_OPTS += -DUSE_QT6=ON

# wayland is currently broken, don't set this...
# ...except on odroid-m1: there's no XWayland at all there (Mali blob has no
# desktop GL), so X11 mode can't actually run regardless of "broken" status -
# Wayland is the only option that has a chance of working.
ifeq ($(BR2_PACKAGE_MALI_G52_ODROIDM1),y)
MELONDS_CONF_OPTS += -DENABLE_WAYLAND=ON
else
MELONDS_CONF_OPTS += -DENABLE_WAYLAND=OFF
endif

define MELONDS_INSTALL_TARGET_CMDS
    $(INSTALL) -D $(@D)/buildroot-build/melonDS \
		$(TARGET_DIR)/usr/bin/
endef

$(eval $(cmake-package))
$(eval $(emulator-info-package))
