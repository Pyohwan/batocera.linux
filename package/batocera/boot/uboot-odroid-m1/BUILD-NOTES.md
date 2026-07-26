# u-boot-rockchip.bin provenance

`u-boot-rockchip.bin` - SPL/idbloader and the main-stage U-Boot FIT image
(ARM Trusted Firmware + U-Boot proper + FDT + a few auxiliary firmware
blobs), concatenated at the offsets U-Boot's own build already computes -
is built entirely from upstream source by this package. It used to be two
files, `u-boot.itb` (built from source) plus a prebuilt `idbloader.img`
blob of unknown origin committed straight into this directory; figuring
out what that blob even was cost this project a lot of time, which is the
whole reason for the source build in the first place. There is no
committed blob left in this package at all now - matches
`uboot-odroid-m1s`, which already did this.

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

## Petitboot interoperability (resolved 2026-07-26)

This card now always boots through the on-board SPI-NOR Petitboot, listed as
"batocera.linux", the same as vanilla Batocera's own `rk3568/odroid-m1`
target and unlike this project's own earlier approach (see history below).

**Why it works at all**: `genimage.cfg`'s `uboot` partition is
`in-partition-table = "no"` - the FIT still sits at its usual 8M offset, but
there is no GPT entry named "uboot". The SPL (Hardkernel's own 2017.09,
untouched) locates U-Boot by GPT entry *name*, so without one it prints
`spl: partition error` and falls through to booting from SPI-NOR instead -
which is exactly what makes the on-board Petitboot run and see this card.
This is deliberate, and matches upstream Batocera's own `genimage.cfg` for
this board, not a regression: a storage device that can boot itself always
outranks Petitboot (Petitboot's own author says as much on the ODROID forum,
t=44346, describing the fix for a similar case as removing the competing
bootloader), so registering that GPT entry - which is what an earlier point
on this branch did, in order to make direct SD boot possible - is exactly
what would make the card boot itself and skip Petitboot.

**Getting listed in the menu** at all needed three fixes together, all in
the board directory - see `board/batocera/rockchip/bsp-odroidm1/boot.cmd`
and the `genimage.cfg` comments for the full detail: Petitboot parses
`boot.ini` / `boot.scr` / `kboot.conf` / `grub.cfg`, not `extlinux.conf`
(the ODROID-M1 Petitboot author's own answer on the forum); its resource
resolution mis-handles a `:<part>` suffix in a script's load commands; and
it only ever finds a bootable OS on GPT entry #1, which the boot partition
now is.

**A second menu entry** (VU8M vs. HDMI-only, as two separate boot options)
was tried and does not work: shipping both a `boot.scr` and a `boot.ini`
produced a single "batocera.linux" entry, not two. Hardkernel's
`uboot-parser` is closed source, but its own author describes it on the
forum as scanning for "the boot script" per partition (singular) - it is not
built the way upstream Petitboot's own parsers are (which do try every
registered parser). So VU8M is controlled by a single shared file instead -
see "Toggling VU8M" below.

**Booting without Petitboot** is still possible, on demand: run
`fw_setenv skip_spiboot true` in the Petitboot shell and reboot, and the
SPI-NOR U-Boot distro-boots straight off this card's `boot.scr` instead of
starting Petitboot (`fw_setenv skip_spiboot false` reverts). This is a
real, documented Hardkernel mechanism (same forum thread), not something
added by this project. There is deliberately no `extlinux.conf` on this
card - distro-boot tries it before `boot.scr`, so having both would make
this path silently skip the `config.ini` logic below instead of using it.

**Toggling VU8M** is a single line in `/boot/config.ini` (`overlays=`),
read the same way on every boot path (Petitboot kexec, `skip_spiboot`
distro-boot, and this project's own U-Boot on the rare occasion its GPT
entry is re-added) since all of them read the same `boot.scr`:

```
mount -o remount,rw /boot
vi /boot/config.ini   # comment out or clear overlays= for HDMI only
reboot
```

This is the exact mechanism Hardkernel's own official Ubuntu image uses -
confirmed by dumping and reading its real `boot.scr` off a live eMMC
install: it loads `config.ini` with the `ini` command, then `fdt apply`s
each name listed in `overlays=`. That Ubuntu install boots correctly with
VU8M active through both Petitboot and `skip_spiboot`, on this exact
board, which is what settled on this design over other options - see
"Earlier approaches" below for what was tried and ruled out first.
`CONFIG_CMD_INI` is enabled in this package's own mainline 2026.04 build
too, so `ini` isn't a Hardkernel-only patch - it works the same way
regardless of which of the three U-Boots actually executes `boot.scr`.

### Earlier approaches (kept for the record, not to be retried)

- **Registering U-Boot as a named GPT entry**, so this card could boot
  itself directly - this project's own approach before the above. Petitboot
  never got past this: with a storage device that can boot itself, boot ROM
  always runs it and SPI-NOR is never reached, no matter what is on the
  card. The instinct that it *should* be possible to have both was reasonable
  and matches how a real bootloader with a proper boot-order setting could
  behave, but the boot ROM here has no such setting - self-booting and
  showing up in Petitboot's menu turned out to be genuinely exclusive.
- **A Hardkernel-fork build of `u-boot.itb`**
  (`github.com/hardkernel/u-boot`, branch `odroidm1-v2017.09`, via their
  `./make.sh odroid_rk3568` wrapper), on the theory that its board-specific
  `rk_board_late_init()` SPI-NOR chain-load would matter here. It built and
  booted (ATF component hashes matched a real SPI-NOR boot), but turned out
  irrelevant: Petitboot's device scan runs entirely on its own in SPI-NOR,
  independent of whatever U-Boot the SD card ships. Worse, that board.c
  unconditionally chain-loads its embedded 4.19.206 recovery kernel, so the
  card's own kernel never ran. Reverted to the mainline build documented
  above.
- **A second Petitboot menu entry** (VU8M vs. HDMI-only as separate boot
  choices, one config file each) - see "A second menu entry" above.
- **Pre-merging VU8M into a second, complete DTB**
  (`rk3568-odroid-m1-active.dtb`), toggled by overwriting that one file over
  SSH - built because `FDTOVERLAYS` in `extlinux.conf` only covered our own
  U-Boot, and this sidestepped needing any boot path to understand overlays
  at all. Worked, but was replaced once `config.ini` + `ini` + `fdt apply`
  was confirmed to work identically on every path anyway (see "Toggling
  VU8M" above), which does the same job without carrying two ~177K DTBs
  instead of one DTB plus a ~3K overlay.

Some things worth knowing if this area is ever touched again, all from
Hardkernel's own Petitboot forum thread (archived under
`~/odroid-forum-archives/`): `uboot-parser <path>` can be run by hand in
the Petitboot shell to see how a script gets parsed, and inside
Petitboot's U-Boot `test -e` always returns false, and `${filesize}` stays
0 after a failed load - which is the real explanation for a long stretch
of marker-file debugging earlier in this project. `uboot-parser` itself is
the one piece Hardkernel never published (its repo is gone), so its
behaviour can only be probed empirically. One distinction worth being
careful about: `env import -t` (the generic uEnv.txt-style mechanism
3rd-party OS images like CoreELEC use to read their own config.ini) is a
*different* thing from the `ini` command Hardkernel's own images use, and
only the former is documented as broken through Petitboot - multiple forum
posts (e.g. rpineau, umiki) report `env import`-sourced settings being
silently dropped when booting through Petitboot but applying fine when
the card boots itself directly. `ini` is not documented as having this
problem anywhere, and empirically doesn't: Hardkernel's own Ubuntu, which
uses it, boots correctly with VU8M active through Petitboot on this exact
board.
