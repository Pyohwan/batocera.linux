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

mkdir -p "${BATOCERA_BINARIES_DIR}/build-uboot-odroid-m1"     || exit 1
cp "${BOARD_DIR}/build-uboot.sh"          "${BATOCERA_BINARIES_DIR}/build-uboot-odroid-m1/" || exit 1
cd "${BATOCERA_BINARIES_DIR}/build-uboot-odroid-m1/" && ./build-uboot.sh "${HOST_DIR}" "${BOARD_DIR}" "${BINARIES_DIR}" || exit 1

mkdir -p "${BATOCERA_BINARIES_DIR}/boot/boot"     || exit 1
mkdir -p "${BATOCERA_BINARIES_DIR}/boot/extlinux" || exit 1

cp "${BINARIES_DIR}/Image"                  "${BATOCERA_BINARIES_DIR}/boot/boot/linux"                || exit 1
cp "${BINARIES_DIR}/initrd.lz4"             "${BATOCERA_BINARIES_DIR}/boot/boot/initrd.lz4"            || exit 1
cp "${BINARIES_DIR}/rootfs.squashfs"        "${BATOCERA_BINARIES_DIR}/boot/boot/batocera.update"      || exit 1
cp "${BINARIES_DIR}/rufomaculata"           "${BATOCERA_BINARIES_DIR}/boot/boot/rufomaculata.update" || exit 1

# Bake VU8M (+ i2c0/i2c1/spi0) overlays statically into the DTB, so the
# second display and its I2C/SPI buses are always enabled without needing
# flash-kernel/config.ini (which don't exist on this distro).
"${HOST_DIR}/bin/fdtoverlay" \
	-i "${BINARIES_DIR}/rk3568-odroid-m1.dtb" \
	-o "${BATOCERA_BINARIES_DIR}/boot/boot/rk3568-odroid-m1.dtb" \
	"${BOARD_DIR}/overlays/display_vu8m.dtbo" \
	"${BOARD_DIR}/overlays/i2c0.dtbo" \
	"${BOARD_DIR}/overlays/i2c1.dtbo" \
	"${BOARD_DIR}/overlays/spi0.dtbo" \
	|| exit 1
cp "${BOARD_DIR}/boot/extlinux.conf"       "${BATOCERA_BINARIES_DIR}/boot/extlinux/" || exit 1
cp "${BOARD_DIR}/boot/boot.scr"            "${BATOCERA_BINARIES_DIR}/boot/"  || exit 1
cp "${BOARD_DIR}/boot/boot-logo.bmp.gz"    "${BATOCERA_BINARIES_DIR}/boot/"  || exit 1

# Matches the sysconfig default (global.videooutput=HDMI-A-1): disables
# DSI-1 from the very first boot, before S66odroidm1display ever gets a
# chance to compute/write this file itself on a shutdown. Without this, a
# fresh flash shows both HDMI and VU8M lit until the first clean
# shutdown/reboot regenerates it correctly.
cp "${BOARD_DIR}/boot/display-bootarg.txt" "${BATOCERA_BINARIES_DIR}/boot/"  || exit 1

exit 0
