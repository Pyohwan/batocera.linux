################################################################################
#
# libretro-beetle-saturn
#
################################################################################
# Version: Commits on October 22, 2024
LIBRETRO_BEETLE_SATURN_VERSION = 0a78a9a5ab0088ba19f21e028dda9f4b4d7c9e48
LIBRETRO_BEETLE_SATURN_SITE = \
    $(call github,libretro,beetle-saturn-libretro,$(LIBRETRO_BEETLE_SATURN_VERSION))
LIBRETRO_BEETLE_SATURN_LICENSE = GPLv2
LIBRETRO_BEETLE_SATURN_DEPENDENCIES += retroarch
LIBRETRO_BEETLE_SATURN_EMULATOR_INFO = beetle-saturn.libretro.core.yml

LIBRETRO_BEETLE_SATURN_PLATFORM = unix

# This board only has GLES (mesa3d-headers, no desktop GL/GLX) - the
# upstream Makefile's HAVE_OPENGL=1 path links against desktop -lGL unless
# "gles" appears in the platform string, in which case it switches to
# -lGLESv2 instead (same pattern as libretro-beetle-psx's "unix-gles").
ifeq ($(BR2_PACKAGE_HAS_LIBGLES),y)
LIBRETRO_BEETLE_SATURN_DEPENDENCIES += libgles
LIBRETRO_BEETLE_SATURN_PLATFORM = unix-gles
endif

define LIBRETRO_BEETLE_SATURN_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" \
	    -C $(@D) -f Makefile HAVE_OPENGL=1 platform="$(LIBRETRO_BEETLE_SATURN_PLATFORM)"
endef

define LIBRETRO_BEETLE_SATURN_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/mednafen_saturn_hw_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/beetle-saturn_libretro.so
endef

$(eval $(generic-package))
$(eval $(emulator-info-package))
