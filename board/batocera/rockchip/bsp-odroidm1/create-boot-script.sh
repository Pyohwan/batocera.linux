#!/bin/bash

# HOST_DIR = host dir
# BOARD_DIR = board specific dir
# BUILD_DIR = base dir/build
# BINARIES_DIR = images dir
# TARGET_DIR = target dir
# BATOCERA_BINARIES_DIR = batocera binaries sub directory

HOST_DIR=$1
BOARD_DIR=$2
BUILD_DIR=$3
BINARIES_DIR=$4
TARGET_DIR=$5
BATOCERA_BINARIES_DIR=$6

mkdir -p "${BATOCERA_BINARIES_DIR}/boot/boot"          || exit 1
mkdir -p "${BATOCERA_BINARIES_DIR}/boot/boot/overlays" || exit 1
mkdir -p "${BATOCERA_BINARIES_DIR}/boot/syslinux"      || exit 1

cp "${BINARIES_DIR}/Image"                  "${BATOCERA_BINARIES_DIR}/boot/boot/linux"                || exit 1
cp "${BINARIES_DIR}/initrd.lz4"             "${BATOCERA_BINARIES_DIR}/boot/boot/initrd.lz4"            || exit 1
cp "${BINARIES_DIR}/rootfs.squashfs"        "${BATOCERA_BINARIES_DIR}/boot/boot/batocera.update"      || exit 1
cp "${BINARIES_DIR}/rufomaculata"           "${BATOCERA_BINARIES_DIR}/boot/boot/rufomaculata.update" || exit 1

# Bake i2c0/i2c1/spi0 statically into the DTB (harmless generic bus
# enablement, no reason to gate those). VU8M is NOT baked in here - it's a
# separate overlay applied at boot time by boot.cmd, driven by config.ini.
# See boot.cmd's own header comment for the full mechanism and why it
# replaced an earlier pre-merged-DTB design, and
# package/batocera/boot/uboot-odroid-m1/BUILD-NOTES.md for the wider story.
"${HOST_DIR}/bin/fdtoverlay" \
	-i "${BINARIES_DIR}/rk3568-odroid-m1.dtb" \
	-o "${BATOCERA_BINARIES_DIR}/boot/boot/rk3568-odroid-m1.dtb" \
	"${BOARD_DIR}/overlays/i2c0.dtbo" \
	"${BOARD_DIR}/overlays/i2c1.dtbo" \
	"${BOARD_DIR}/overlays/spi0.dtbo" \
	|| exit 1

cp "${BOARD_DIR}/overlays/display_vu8m.dtbo" "${BATOCERA_BINARIES_DIR}/boot/boot/overlays/display_vu8m.dtbo" || exit 1

# Toggling VU8M at runtime, on every boot path this board can use (Petitboot,
# skip_spiboot, and this project's own U-Boot on the rare occasion its GPT
# entry comes back), means SSHing in and editing this one line:
#
#   mount -o remount,rw /boot
#   vi /boot/config.ini   # overlays="display_vu8m" to enable, "" to disable
#   reboot
#
# Ships with overlays="" (HDMI only) by default. Applying the panel
# unconditionally used to cause a whole class of bugs this project spent a
# long time on: HDMI is a plain always-on DT node (not overlay-gated), so
# with VU8M's DSI panel also probed, EmulationStation's KMSDRM output ends
# up with two connectors to choose from even when the user only ever wants
# HDMI - the "unused" DSI-1 then needed to be actively hidden every boot
# (DPMS blanking, which fought with batocera-switch-screen-checker's
# hotplug detection, plus got undone again by ES's own screensaver ~every 5
# minutes - both root-caused and both real, see the PR body's "Known
# issues" history). ES itself still ends up picking HDMI correctly with the
# overlay enabled (global.videooutput prefers it), but the boot splash runs
# before that logic and doesn't know which connector to draw to when both
# exist - defaulting to disabled avoids that cosmetic glitch for the common
# case, at the cost of an SSH edit for VU8M users.
cp "${BOARD_DIR}/boot/config.ini"          "${BATOCERA_BINARIES_DIR}/boot/config.ini" || exit 1

cp "${BOARD_DIR}/boot/boot-logo.bmp.gz"    "${BATOCERA_BINARIES_DIR}/boot/"  || exit 1

# boot.scr: the only boot script on this card, and what makes it show up in
# the on-board SPI-NOR Petitboot menu at all (Petitboot understands
# boot.ini/boot.scr/kboot.conf/grub.cfg, not extlinux.conf - the ODROID-M1
# Petitboot author's own answer on the ODROID forum, t=44346). There used to
# be an extlinux.conf too, for our own U-Boot's benefit, but distro-boot
# tries extlinux.conf before boot.scr - keeping both would make any real
# U-Boot silently prefer the extlinux.conf path over this script's
# config.ini-driven VU8M logic. Hardkernel's own Ubuntu image ships no
# extlinux.conf either, for the same reason - see boot.cmd's own header
# comment for the rest of that story.
# Compiled here rather than shipped as a committed binary so it can never
# drift out of sync with boot.cmd - which is exactly what happened before:
# boot.cmd was believed to be dead code and deleted, silently taking
# Petitboot discovery with it. See BUILD-NOTES.md for the full story.
# Path is the boot partition's root, matching both Hardkernel's own
# flash-kernel layout and vanilla Batocera's (which did get listed).
"${HOST_DIR}/bin/mkimage" -A arm64 -T script -C none \
	-d "${BOARD_DIR}/boot.cmd" \
	"${BATOCERA_BINARIES_DIR}/boot/boot.scr" || exit 1

# Kept alongside boot.scr: upstream Petitboot also has a syslinux parser
# that wants a file literally named "syslinux.cfg" with lowercase
# directives (its matching is case-sensitive strcmp, unlike U-Boot's own
# extlinux parser). On its own this was NOT enough to get listed - hence
# boot.scr above - but it costs nothing to keep and covers that parser
# too if a given Petitboot build happens to include it.
cp "${BOARD_DIR}/boot/syslinux.cfg"        "${BATOCERA_BINARIES_DIR}/boot/syslinux/syslinux.cfg" || exit 1

exit 0
