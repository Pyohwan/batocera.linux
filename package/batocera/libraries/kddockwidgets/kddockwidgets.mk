################################################################################
#
# kddockwidgets
#
################################################################################

KDDOCKWIDGETS_VERSION = v2.3.0
KDDOCKWIDGETS_SITE = https://github.com/KDAB/KDDockWidgets
KDDOCKWIDGETS_SITE_METHOD = git
KDDOCKWIDGETS_GIT_SUBMODULES = YES
KDDOCKWIDGETS_LICENSE = GPLv2 or GPLv3
KDDOCKWIDGETS_LICENSE_FILES = LICENSE.GPL.txt LICENSE.txt
KDDOCKWIDGETS_DEPENDENCIES = qt6base
KDDOCKWIDGETS_SUPPORTS_IN_SOURCE_BUILD = NO

KDDOCKWIDGETS_INSTALL_STAGING = YES

KDDOCKWIDGETS_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
KDDOCKWIDGETS_CONF_OPTS += -DKDDockWidgets_FRONTENDS=qtwidgets
KDDOCKWIDGETS_CONF_OPTS += -DKDDockWidgets_QT6=ON
KDDOCKWIDGETS_CONF_OPTS += -DKDDockWidgets_EXAMPLES=OFF
KDDOCKWIDGETS_CONF_OPTS += -DECM_MKSPECS_INSTALL_DIR=/usr/mkspecs/modules

# src/qtwidgets/views/ClassicIndicatorsWindow.cpp includes
# QtGui/private/qtx11extras_p.h whenever QT_VERSION>=6 && Linux, regardless
# of whether Qt6 actually has xcb support built in. This board's qt6base
# has no xcb feature (Wayland-only, same reasoning as melonDS's
# MELONDS_FIX_WAYLAND_ONLY_WINDOWINFO fix), so the header doesn't exist.
# The only symbol from it (QX11Info::isCompositingManagerRunning) is
# already runtime-guarded by isXCB() (always false on Wayland), so drop
# the include and that dead branch instead of rebuilding qt6base with
# xcb just to satisfy unreachable code.
define KDDOCKWIDGETS_FIX_X11EXTRAS_INCLUDE
    python3 -c "\
p = '$(@D)/src/qtwidgets/views/ClassicIndicatorsWindow.cpp'; \
s = open(p).read(); \
old_include = '''#ifdef QT_X11EXTRAS_LIB\n#include <QtX11Extras/QX11Info>\n#elif QT_VERSION >= QT_VERSION_CHECK(6, 0, 0) && defined(Q_OS_LINUX)\n#include <QtGui/private/qtx11extras_p.h>\n#endif\n'''; \
old_branch = '''#if defined(QT_X11EXTRAS_LIB) || (QT_VERSION >= QT_VERSION_CHECK(6, 0, 0) && defined(Q_OS_LINUX))\n    if (isXCB())\n        return QX11Info::isCompositingManagerRunning();\n#endif\n\n    // macOS and Windows are fine\n    return true;\n'''; \
new_branch = '''    // macOS, Windows, and Wayland (this board) are fine\n    return true;\n'''; \
assert old_include in s and old_branch in s, 'kddockwidgets ClassicIndicatorsWindow.cpp X11 block not found - upstream source changed, review this patch'; \
s = s.replace(old_include, '', 1).replace(old_branch, new_branch, 1); \
open(p, 'w').write(s)"
endef
KDDOCKWIDGETS_PRE_CONFIGURE_HOOKS += KDDOCKWIDGETS_FIX_X11EXTRAS_INCLUDE

$(eval $(cmake-package))
