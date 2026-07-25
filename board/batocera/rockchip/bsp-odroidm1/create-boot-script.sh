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

mkdir -p "${BATOCERA_BINARIES_DIR}/boot/boot"          || exit 1
mkdir -p "${BATOCERA_BINARIES_DIR}/boot/boot/overlays" || exit 1
mkdir -p "${BATOCERA_BINARIES_DIR}/boot/extlinux"      || exit 1

cp "${BINARIES_DIR}/Image"                  "${BATOCERA_BINARIES_DIR}/boot/boot/linux"                || exit 1
cp "${BINARIES_DIR}/initrd.lz4"             "${BATOCERA_BINARIES_DIR}/boot/boot/initrd.lz4"            || exit 1
cp "${BINARIES_DIR}/rootfs.squashfs"        "${BATOCERA_BINARIES_DIR}/boot/boot/batocera.update"      || exit 1
cp "${BINARIES_DIR}/rufomaculata"           "${BATOCERA_BINARIES_DIR}/boot/boot/rufomaculata.update" || exit 1

# Bake i2c0/i2c1/spi0 statically into the DTB (harmless generic bus
# enablement, no reason to gate those). VU8M itself is NOT baked in here -
# it ships as a standalone .dtbo below and gets conditionally applied at
# boot time by U-Boot's own `FDTOVERLAYS` directive in extlinux.conf (see
# boot/extlinux.conf - the FDTOVERLAYS line is only present in the
# "batocera-vu8m" LABEL, selected via the file's DEFAULT line). This
# requires package/batocera/boot/uboot-odroid-m1/u-boot.itb to be the
# mainline U-Boot 2026.04 build (odroid-m1-rk3568_defconfig) - the
# previously-shipped prebuilt blob had no FDTOVERLAYS support at all
# (confirmed by testing: silently ignored, no error). SPL/idbloader.img
# is untouched (still Hardkernel's own, already proven reliable on
# hardware) - only the main-stage FIT image changed.
# Baking VU8M in unconditionally is what caused a whole class of bugs this
# project spent a long time on: HDMI is a plain always-on DT node (not
# overlay-gated), so with VU8M's DSI panel also unconditionally probed,
# EmulationStation's KMSDRM output ends up with two connectors to choose
# from even when the user only ever wants HDMI - the "unused" DSI-1 then
# needed to be actively hidden every boot (DPMS blanking, which fought
# with batocera-switch-screen-checker's hotplug detection, plus got undone
# again by ES's own screensaver ~every 5 minutes - both root-caused and
# both real, see the PR body's "Known issues" history). When VU8M isn't
# wanted, the DSI panel should never be probed by the kernel at all, so
# there's nothing left to hide.
"${HOST_DIR}/bin/fdtoverlay" \
	-i "${BINARIES_DIR}/rk3568-odroid-m1.dtb" \
	-o "${BATOCERA_BINARIES_DIR}/boot/boot/rk3568-odroid-m1.dtb" \
	"${BOARD_DIR}/overlays/i2c0.dtbo" \
	"${BOARD_DIR}/overlays/i2c1.dtbo" \
	"${BOARD_DIR}/overlays/spi0.dtbo" \
	|| exit 1

cp "${BOARD_DIR}/overlays/display_vu8m.dtbo" "${BATOCERA_BINARIES_DIR}/boot/boot/overlays/display_vu8m.dtbo" || exit 1

cp "${BOARD_DIR}/boot/extlinux.conf"       "${BATOCERA_BINARIES_DIR}/boot/extlinux/" || exit 1
cp "${BOARD_DIR}/boot/boot-logo.bmp.gz"    "${BATOCERA_BINARIES_DIR}/boot/"  || exit 1

exit 0
