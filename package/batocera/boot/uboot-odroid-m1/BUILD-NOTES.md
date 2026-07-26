# u-boot.itb provenance

`u-boot.itb` - the **main-stage** U-Boot FIT image (ARM Trusted Firmware +
U-Boot proper + FDT + a few auxiliary firmware blobs) - is built from
upstream source by this package. It used to be a prebuilt binary committed
straight into this directory, of unknown origin; figuring out what that
thing even was cost this project a lot of time, which is the whole reason
for the source build.

`idbloader.img` is the one file here that is still a committed blob. It is
Hardkernel's own SPL (`U-Boot SPL 2017.09`), it is the stage the boot ROM
itself validates, and it is proven on this board - replacing it is the
single change in this area that can leave the board unbootable, so it is
deliberately left alone. Only the FIT image that this SPL loads at a fixed
sector offset (8M) is built here.

## Source

- U-Boot `2026.04`, from `https://ftp.denx.de/pub/u-boot/` (the same
  version and site batocera's `uboot-rk356x` package already uses).
- Config: `odroid-m1-rk3568_defconfig`, **unmodified**. Upstream U-Boot
  carries a real, maintained defconfig for this exact board, so there are
  no patches and no config fragments - which is also why no U-Boot fork is
  needed anywhere in this project.

## Firmware blobs (rkbin)

From `https://github.com/rockchip-linux/rkbin`, commit
`74213af1e952c4683d2e35952507133b61394862` (the same pinned commit
batocera's `rockchip-rkbin` and `uboot-rk356x` packages already use) - the
"standard" RK3568 combo per `RKBOOT/RK3568MINIALL.ini`:

- `BL31=bin/rk35/rk3568_bl31_v1.45.elf`
- `ROCKCHIP_TPL=bin/rk35/rk3568_ddr_1560MHz_v1.23.bin`

(No `TEE=` - rk3568 rkbin has no OP-TEE blob, matching this board's real
boot log: "WARNING: No OPTEE provided by BL2 boot loader". `ROCKCHIP_TPL`
only affects SPL-stage output, which this package discards, but it is
pinned anyway so the build stays identical to the hand-built FIT that was
originally verified on hardware.)

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

Those three were established with a hand-built FIT, before this package
built anything. When the build moved in-tree, the package's output was
diffed against that same verified FIT to show it is the same thing: the
image set (`u-boot`, `atf-1`..`atf-6`, `fdt-1`, `config-1`), every load and
entry address, and the device tree are identical, and all six ATF
components match bit for bit - i.e. the rkbin pinning above is exactly
right. The only difference is 56 bytes in `u-boot` itself (plus the data
offsets that shift behind it), which is the cross toolchain and build
timestamp changing, not the source or the config.

## Petitboot interoperability (resolved 2026-07-25)

A Hardkernel-fork build of `u-boot.itb` (`github.com/hardkernel/u-boot`,
branch `odroidm1-v2017.09`, via their `./make.sh odroid_rk3568` wrapper)
was tried in the hope that its board-specific `rk_board_late_init()`
SPI-NOR chain-load would make this card visible in the SPI-NOR Petitboot
menu. It built and booted (confirmed by matching ATF component hashes
against a real SPI-NOR boot), but turned out to be irrelevant: Petitboot's
device scan runs entirely on its own in SPI-NOR, independent of whatever
U-Boot the SD card ships. Worse, that board.c unconditionally chain-loads
its embedded 4.19.206 recovery kernel, so the card's own kernel never got
to run. **Reverted to the mainline build documented above.**

What actually made Petitboot list this card is in the board directory, not
here - see `board/batocera/rockchip/bsp-odroidm1/boot.cmd` and the
`genimage.cfg` comments. In short: Petitboot parses `boot.ini` /
`boot.scr` / `kboot.conf` / `grub.cfg` and not `extlinux.conf`, its
resource resolution mis-handles a `:<part>` suffix in the script's load
commands, and it effectively needs the boot partition to be #1. All three
had been broken by earlier commits on this branch that judged them dead
from our own boot chain's perspective.

That last one collided with a separate, genuine SPL requirement: SPL
locates U-Boot by GPT entry *name* ("uboot" - Hardkernel's wiki is right
about this, an earlier UART reading that concluded otherwise was wrong),
so that entry can't simply be dropped either. Both are satisfied at once
by declaring the boot partition first in `genimage.cfg` - genimage numbers
GPT entries by declaration order, not by on-disk offset - so the boot
partition becomes GPT #1 for Petitboot while "uboot" keeps its own named
entry (now #3) at its original offset for the SPL. Verified end to end on
hardware, all three at once, in the same image: SPL finds `u-boot.itb` at
GPT #3 fine, direct SD boot takes the `extlinux.conf` path with the VU8M
toggle intact, and the card appears as "batocera.linux" in Petitboot and
kexecs into our real 6.1 kernel.

Two things worth knowing if this area is ever touched again, both from
Hardkernel's own Petitboot forum thread (archived under
`~/odroid-forum-archives/`): `uboot-parser <path>` can be run by hand in
the Petitboot shell to see how a script gets parsed, and inside
Petitboot's U-Boot `test -e` always returns false, `env import -t`
reports success without loading anything, and `${filesize}` stays 0 -
which is the real explanation for a long stretch of marker-file debugging
earlier in this project. `uboot-parser` itself is the one piece
Hardkernel never published (its repo is gone), so its behaviour can only
be probed empirically.
