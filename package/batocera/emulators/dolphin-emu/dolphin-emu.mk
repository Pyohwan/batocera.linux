################################################################################
#
# dolphin-emu
#
################################################################################
# On Wayland boards, the stock commit below has no VK_USE_PLATFORM_WAYLAND_KHR
# support at all (confirmed via source read: VulkanLoader.h/VKSwapChain.cpp
# only handle Win32/Xlib/Android/Metal) - Vulkan surface creation fails
# outright under labwc/Wayland. ROCKNIX hits the exact same gap on their own
# Wayland+Vulkan RK3566 devices and solves it by pinning a newer upstream
# commit plus their own "add-wayland" patch series (verified: applies clean
# with `patch -p1`, no fuzz beyond padorder/git/bios-dir housekeeping patches
# - see ODROID-M1 Track C notes). We mirror that combo here rather than
# hand-porting the patch onto the older commit.
ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND),y)
DOLPHIN_EMU_VERSION = e6583f8bec814d8f3748f1d7738457600ce0de56
else
# Version: Commits on Jun 25, 2026
# Add major & minor version accordingly for any bump
DOLPHIN_EMU_VERSION = 6094cfcf7b8fba733b3116fdf3414d51c1c0e4a4
DOLPHIN_EMU_VERSION_MAJOR = 2606
DOLPHIN_EMU_VERSION_MINOR =
endif
DOLPHIN_EMU_SITE = https://github.com/dolphin-emu/dolphin
DOLPHIN_EMU_SITE_METHOD = git
DOLPHIN_EMU_LICENSE = GPLv2+
DOLPHIN_EMU_GIT_SUBMODULES = YES
DOLPHIN_EMU_SUPPORTS_IN_SOURCE_BUILD = NO

DOLPHIN_EMU_DEPENDENCIES = libevdev ffmpeg zlib libpng lzo libusb libcurl
DOLPHIN_EMU_DEPENDENCIES += bluez5_utils hidapi xz host-xz sdl3 cpp-ipc

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND),y)
DOLPHIN_EMU_DEPENDENCIES += wayland wayland-protocols libxkbcommon ecm
endif

$(eval $(call register,dolphin.emulator.yml))
$(eval $(call register-if-kconfig,BR2_PACKAGE_BATOCERA_VULKAN,gfxbackend.dolphin.emulator.yml))

DOLPHIN_EMU_CONF_OPTS  = -DCMAKE_BUILD_TYPE=Release
DOLPHIN_EMU_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
DOLPHIN_EMU_CONF_OPTS += -DDISTRIBUTOR='batocera.linux'
DOLPHIN_EMU_CONF_OPTS += -DUSE_DISCORD_PRESENCE=OFF
DOLPHIN_EMU_CONF_OPTS += -DUSE_MGBA=OFF
DOLPHIN_EMU_CONF_OPTS += -DUSE_UPNP=OFF
DOLPHIN_EMU_CONF_OPTS += -DENABLE_TESTS=OFF
DOLPHIN_EMU_CONF_OPTS += -DENABLE_AUTOUPDATE=OFF
DOLPHIN_EMU_CONF_OPTS += -DENABLE_ANALYTICS=OFF
DOLPHIN_EMU_CONF_OPTS += -DUSE_SYSTEM_LIBS=AUTO
DOLPHIN_EMU_CONF_OPTS += -DUSE_SYSTEM_FMT=OFF
DOLPHIN_EMU_CONF_OPTS += -DENABLE_CLI_TOOL=OFF
DOLPHIN_EMU_CONF_OPTS += -DUSE_RETRO_ACHIEVEMENTS=ON

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND),y)
# The Wayland patch series only wires native Wayland support into
# DolphinNoGUI's Platform abstraction, not into the Qt GUI's window widget
# (confirmed: patch touches zero Qt source files) - so Wayland boards must
# use the NoGUI/dolphin-emu-nogui binary regardless of Qt6 availability.
DOLPHIN_EMU_CONF_OPTS += -DENABLE_QT=OFF
DOLPHIN_EMU_CONF_OPTS += -DENABLE_NOGUI=ON
DOLPHIN_EMU_CONF_OPTS += -DENABLE_WAYLAND=ON
# This older source tree's bundled Externals (e.g. enet) declare
# cmake_minimum_required() below 3.5, which current CMake rejects outright
# rather than just warning (matches ROCKNIX's own package.mk, which carries
# the same flag for this exact commit).
DOLPHIN_EMU_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5
# This source predates fmt's compile-time format-string API overhaul (it
# was written against the fmt 9.1.0 it bundles in Externals/fmt) and fails
# to build against this board's shared system fmt (12.1.0 - fmt::detail::
# is_compile_string and the FMT_COMPILE_STRING conversion path it relies on
# are gone). CMakeLists.txt already falls back to the bundled Externals/fmt
# whenever find_package(fmt) doesn't find one, so force that fallback
# instead of chasing fmt's internal API across 3 major versions.
DOLPHIN_EMU_CONF_OPTS += -DCMAKE_DISABLE_FIND_PACKAGE_fmt=TRUE
else
ifeq ($(BR2_PACKAGE_QT6),y)
DOLPHIN_EMU_DEPENDENCIES += qt6base qt6svg
DOLPHIN_EMU_CONF_OPTS += -DENABLE_QT=ON
DOLPHIN_EMU_CONF_OPTS += -DENABLE_NOGUI=OFF
else
DOLPHIN_EMU_CONF_OPTS += -DENABLE_QT=OFF
DOLPHIN_EMU_CONF_OPTS += -DENABLE_NOGUI=ON
endif
endif

DOLPHIN_EMU_MAKE_ENV += LDFLAGS="-Wl,--copy-dt-needed-entries"
DOLPHIN_EMU_CONF_ENV += LDFLAGS="-Wl,--copy-dt-needed-entries"

ifeq ($(BR2_PACKAGE_XORG7),y)
    DOLPHIN_EMU_CONF_OPTS += -DENABLE_X11=ON
else
    DOLPHIN_EMU_CONF_OPTS += -DENABLE_X11=OFF
endif

ifeq ($(BR2_PACKAGE_BATOCERA_VULKAN),y)
    DOLPHIN_EMU_CONF_OPTS += -DENABLE_VULKAN=ON
else
    DOLPHIN_EMU_CONF_OPTS += -DENABLE_VULKAN=OFF
endif

ifneq ($(DOLPHIN_EMU_VERSION_MAJOR),)
define DOLPHIN_EMU_PRE_CONFIGURE_HOOK
    sed -i 's/set(DOLPHIN_VERSION_MAJOR .*)/set(DOLPHIN_VERSION_MAJOR "$(DOLPHIN_EMU_VERSION_MAJOR)")/' \
        $(@D)/CMake/ScmRevGen.cmake
    sed -i 's/set(DOLPHIN_VERSION_MINOR .*)/set(DOLPHIN_VERSION_MINOR "$(DOLPHIN_EMU_VERSION_MINOR)")/' \
        $(@D)/CMake/ScmRevGen.cmake
endef
DOLPHIN_EMU_PRE_CONFIGURE_HOOKS = DOLPHIN_EMU_PRE_CONFIGURE_HOOK
endif

define DOLPHIN_EMU_INI
    mkdir -p $(TARGET_DIR)/usr/share/dolphin-emu/sys/GameSettings
    # copy extra triforce ini files - force overwrite
    cp -pr $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/dolphin-emu/*.ini \
		$(TARGET_DIR)/usr/share/dolphin-emu/sys/GameSettings
    # NoGUI-only builds (Wayland boards) never install a dolphin-emu Qt binary
    if [ -f $(TARGET_DIR)/usr/bin/dolphin-emu ]; then \
		cd $(TARGET_DIR)/usr/bin && ln -sf dolphin-emu dolphin-emu.desktopconfig; \
	fi
endef

DOLPHIN_EMU_POST_INSTALL_TARGET_HOOKS += DOLPHIN_EMU_INI

$(eval $(cmake-package))
$(eval $(emulator-info-package))
