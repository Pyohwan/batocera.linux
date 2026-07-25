# u-boot.itb provenance

`u-boot.itb` in this directory is the **main-stage** U-Boot FIT image
(ARM Trusted Firmware + U-Boot proper + FDT + a few auxiliary firmware
blobs), built from real upstream source - not a prebuilt vendor blob of
unknown origin (that was the previous state of this file, and figuring
out what it even was cost a lot of time).

`idbloader.img` in this directory is **not** rebuilt by this process and
is left untouched - it's Hardkernel's own SPL (`U-Boot SPL 2017.09`),
already proven reliable on hardware. Only the FIT image that the SPL
loads at a fixed sector offset (8M) was replaced.

## Source

- U-Boot version: `2026.04` (same version buildroot's `uboot-tools`
  package already fetches from `https://ftp.denx.de/pub/u-boot/`, since
  this source tree turned out to already contain a real, upstream-
  maintained defconfig for this exact board: `configs/odroid-m1-rk3568_defconfig`).
- Config: unmodified `odroid-m1-rk3568_defconfig` except
  `CONFIG_TOOLS_MKEFICAPSULE` disabled (that host tool needs `gnutls-dev`,
  which isn't relevant to what we ship - no U-Boot source patches applied).

## Firmware blobs (rkbin)

From `https://github.com/rockchip-linux/rkbin.git`, commit
`74213af1e952c4683d2e35952507133b61394862` (same pinned commit batocera's
`rockchip-rkbin` buildroot package already uses for other rk3568/rk3588
boards) - the "standard" RK3568 combo per `RKBOOT/RK3568MINIALL.ini`:

- `BL31=bin/rk35/rk3568_bl31_v1.45.elf`
- `ROCKCHIP_TPL=bin/rk35/rk3568_ddr_1560MHz_v1.23.bin`

(No `TEE=` - rk3568 rkbin has no OP-TEE blob, matches this board's real
boot log: "WARNING: No OPTEE provided by BL2 boot loader".)

## Build

```bash
git clone --branch v2026.04 https://github.com/u-boot/u-boot.git u-boot-src
cd u-boot-src
export CROSS_COMPILE=aarch64-linux-gnu-   # any aarch64 gcc toolchain
make odroid-m1-rk3568_defconfig
sed -i 's/CONFIG_TOOLS_MKEFICAPSULE=y/# CONFIG_TOOLS_MKEFICAPSULE is not set/' .config
make olddefconfig
make -j"$(nproc)" \
  BL31=/path/to/rkbin/bin/rk35/rk3568_bl31_v1.45.elf \
  ROCKCHIP_TPL=/path/to/rkbin/bin/rk35/rk3568_ddr_1560MHz_v1.23.bin
cp u-boot.itb /path/to/batocera.linux/package/batocera/boot/uboot-odroid-m1/u-boot.itb
```

## Verified on hardware (2026-07-25)

- SPL (Hardkernel 2017.09, untouched) validates and jumps into this FIT
  correctly, including its extra `atf-4`/`atf-5`/`atf-6` loadables (the
  old blob's FIT only had `atf-2`/`atf-3` - one more component than the
  old SPL log ever showed, but SPL doesn't care and loads them fine).
- `extlinux.conf`'s `FDTOVERLAYS` directive works (the old blob silently
  ignored it - no error, no attempt to load the overlay file).
- Editing `extlinux.conf` at runtime via SSH (`mount -o remount,rw /boot`)
  and rebooting is read correctly by this build's FAT driver - the old
  blob's FAT driver could only reliably read files written by mtools at
  image-build time.
