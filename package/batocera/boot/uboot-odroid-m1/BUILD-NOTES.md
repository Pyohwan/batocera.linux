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

## Verified on hardware

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

## Petitboot auto-discovery investigation (2026-07-25, not yet solved)

A separate, real Hardkernel-fork build of `u-boot.itb`
(`github.com/hardkernel/u-boot`, branch `odroidm1-v2017.09`, built via
their `./make.sh odroid_rk3568` wrapper) was tried specifically to get
this SD card to show up as a boot option in the on-board SPI-NOR
Petitboot menu. It built and booted fine (confirmed via matching ATF
component SHA256 hashes against a real SPI-NOR boot), and does carry
`board/hardkernel/odroid-common/board.c`'s `rk_board_late_init()`
(chain-loads a Petitboot `boot.scr` from SPI-NOR flash on every boot
unless `skip_spiboot=true`) - but this turned out to be irrelevant to
Petitboot's own device-scan, which runs entirely independently in SPI-NOR
regardless of what U-Boot the SD card itself ships. It was **reverted
back to this mainline build** - no upside for the added risk (this
board.c also introduced a real regression: with a default env, the SD's
own kernel never got a chance to run at all, because the vendor's own
`boot.scr` unconditionally kexecs its embedded 4.19.206 recovery kernel
instead of falling through to `distro_bootcmd`).

Root cause for why Petitboot doesn't list this card, as far as we got:
real upstream Petitboot (`open-power/petitboot`) has a
`discover/syslinux-parser.c` that looks for a file literally named
`syslinux.cfg` (not `extlinux.conf`) at `/syslinux/syslinux.cfg` and a
couple other fixed paths - added here
(`board/batocera/rockchip/bsp-odroidm1/boot/syslinux.cfg`, copied to that
path by `create-boot-script.sh`). Its directive matching is also
case-sensitive (`strcmp` against lowercase literals, no
`tolower()`/`strcasecmp()` anywhere in the parser - confirmed by reading
the source), so the file uses lowercase `label`/`linux`/`append` unlike
our uppercase `extlinux.conf`. Confirmed via
`/var/log/petitboot/pb-discover.log` on real hardware that Petitboot
mounts our SD partition fine and does run its parsers on it ("trying
parsers for mmcblk1p2"), but even with the correct filename, correct
path, and correct (lowercase) syntax, it still resolves zero boot
options - unlike every other partition on the same board (Ubuntu
installs on NVMe/eMMC), which Petitboot lists correctly via some other
mechanism we could not identify (no `grub.cfg`, no BLS
`/boot/loader/entries/`, no `*.cmdline.sig` files exist on those
partitions either, so it isn't obviously the grub2/BLS parser as
tested against upstream's own parser sources).

Working hypothesis: Hardkernel's actual compiled Petitboot binary
(source not published, request for access unanswered) most likely just
doesn't include the syslinux/extlinux parser at all, or has it patched
out - this is unverifiable without their source. The `syslinux.cfg` file
is left in place regardless (harmless, and would start working for free
if that hypothesis is wrong or a future Petitboot rebuild fixes it) but
should not be assumed to work.

Not pursued further: manual "New" entries in the Petitboot UI do work
(confirmed live, including a full boot through to EmulationStation via
kexec from the old 4.19 recovery kernel, tolerating a `ITS queue timeout`
retry loop that stalls boot for a couple minutes but does not appear to
be fatal) and Petitboot does have env-backed persistence for a
remembered default device (`petitboot,bootdevs=`, `petitboot,write?=true`
observed in the shared SPI-NOR U-Boot env) - but a from-scratch manual
entry did not survive a subsequent reboot in testing, and this path was
deliberately not pursued further as the primary solution per explicit
project direction (manual/non-automatic registration treated as a last
resort, not a real fix).
