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
# melonDS's Qt frontend does an unconditional find_package(X11 REQUIRED) on
# Linux (src/frontend/qt_sdl/CMakeLists.txt), regardless of ENABLE_WAYLAND -
# this is a build-time link dependency only, not a runtime X server
# requirement (this board has no Xorg/XWayland running at all, same
# xlib_libX11-as-build-dep pattern already used by raze/gzdoom/moonlight-qt).
MELONDS_DEPENDENCIES += xlib_libX11

MELONDS_SUPPORTS_IN_SOURCE_BUILD = NO

MELONDS_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
MELONDS_CONF_OPTS += -DCMAKE_INSTALL_PREFIX="/usr"
MELONDS_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
MELONDS_CONF_OPTS += -DUSE_QT6=ON

# Upstream's own "wayland is currently broken" comment predates this
# board's setup and applied generically; qt6wayland is already built and
# working here (dolphin-emu's native Wayland platform depends on it), so
# use native Wayland for melonDS's GL window handle path (needed for the
# dual-screen ES feature - see Screen.cpp fix below for why this alone
# isn't enough to build cleanly).
ifeq ($(BR2_PACKAGE_QT6WAYLAND),y)
MELONDS_CONF_OPTS += -DENABLE_WAYLAND=ON
MELONDS_DEPENDENCIES += qt6wayland wayland wayland-protocols libxkbcommon
else
MELONDS_CONF_OPTS += -DENABLE_WAYLAND=OFF
endif

# src/frontend/qt_sdl/Screen.cpp's getWindowInfo() unconditionally
# references QX11Application (Qt6 >= 6.5's xcb-only native interface
# class) in an `if (platformName() == "xcb")` branch that isn't gated on
# ENABLE_WAYLAND at all - it's checked purely by QT_VERSION. This board's
# qt6base has no xcb feature (BR2_PACKAGE_QT6BASE_XCB unset, Wayland-only,
# no X11 libs in target sysroot beyond the build-time-only xlib_libX11
# above), so QX11Application doesn't exist and the type fails to compile
# even though the branch is unreachable at runtime here (platformName()
# is always "wayland" on this board). Turning on xcb support just to
# satisfy dead code would mean rebuilding all of qt6base (one of the
# largest packages in this build) - drop the xcb branch instead and make
# the wayland branch (which already exists and does the real work here)
# unconditional. Confirmed no other file references QX11Application.
#
# Second, separate upstream bug found while fixing the above: the wayland
# branch is guarded by `#if defined(ENABLE_WAYLAND) && ENABLE_WAYLAND`,
# but CMakeLists.txt (this same source tree, line ~148) only ever defines
# a *differently-named* macro, WAYLAND_ENABLED (target_compile_definitions
# ... WAYLAND_ENABLED) - confirmed this is the real macro via
# duckstation/gl/context.cpp's own `#ifdef WAYLAND_ENABLED` usage. So the
# wayland branch was dead code even in unpatched upstream melonDS
# regardless of the CMake ENABLE_WAYLAND option's value - fixed to check
# the macro CMake actually defines.
define MELONDS_FIX_WAYLAND_ONLY_WINDOWINFO
    python3 -c "\
p = '$(@D)/src/frontend/qt_sdl/Screen.cpp'; \
s = open(p).read(); \
old = '''    #if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)\n    if (platform_name == QStringLiteral(\"xcb\"))\n    {\n        wi.type = WindowInfo::Type::X11;\n        const QX11Application* x11 = qApp->nativeInterface<QX11Application>();\n        wi.display_connection = x11->display();\n        wi.window_handle = reinterpret_cast<void*>(winId());\n    }\n    #if defined(ENABLE_WAYLAND) && ENABLE_WAYLAND\n    else if (platform_name == QStringLiteral(\"wayland\"))\n'''; \
new = '''    #if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)\n    #if defined(WAYLAND_ENABLED)\n    if (platform_name == QStringLiteral(\"wayland\"))\n'''; \
assert old in s, 'melonDS Screen.cpp xcb block not found - upstream source changed, review this patch'; \
open(p, 'w').write(s.replace(old, new, 1))"
endef
MELONDS_PRE_CONFIGURE_HOOKS += MELONDS_FIX_WAYLAND_ONLY_WINDOWINFO

define MELONDS_INSTALL_TARGET_CMDS
    $(INSTALL) -D $(@D)/buildroot-build/melonDS \
		$(TARGET_DIR)/usr/bin/
endef

$(eval $(cmake-package))
$(eval $(emulator-info-package))
