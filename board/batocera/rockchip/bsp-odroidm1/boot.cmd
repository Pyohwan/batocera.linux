#
# flash-kernel: bootscr.odroid-rk356x
#
# Compiled to boot.scr at build time (see create-boot-script.sh) and shipped
# on the boot partition. This is the ONLY boot script on this card - see
# "One script, not extlinux.conf" below for why extlinux.conf is gone.
#
# Read by three different things, all proven on hardware:
#   - the on-board SPI-NOR Petitboot (kexec, via its closed-source
#     uboot-parser - this is what makes the card show up as "batocera.linux"
#     in its menu at all: Petitboot understands boot.ini/boot.scr/kboot.conf/
#     grub.cfg, not extlinux.conf, per the ODROID-M1 Petitboot author's own
#     answer on the ODROID forum, thread t=44346);
#   - the SPI-NOR's real Hardkernel 2017.09 U-Boot, when `fw_setenv
#     skip_spiboot true` makes it distro-boot straight off this card instead
#     of starting Petitboot;
#   - this project's own mainline 2026.04 U-Boot, on the rare occasion its
#     GPT entry is re-added (see genimage.cfg).
#
# Written with literal paths and minimal variable use on purpose:
# Petitboot's parser does not fully evaluate U-Boot variables, and
# unresolved ones silently become empty - which is how the DietPi HC4
# report (MichaIng/DietPi#5336) ended up with a zero-length dtb.
#
# Critically, the load commands pass "${devtype} ${devnum}" with NO
# ":<part>" suffix. Petitboot turns each load target into a resource
# string and, per upstream's create_devpath_resource(), only treats it as
# "belongs to some other device" when it contains a colon - otherwise it
# resolves immediately against the partition it is currently scanning,
# which is exactly what we want. With a "${devnum}:${partition}" form the
# parser substitutes a device name but gets the partition index wrong
# (always landing on p1), and every resource stays permanently
# unresolved: confirmed live via pb-discover.log, which parsed this script
# fine and created the "batocera.linux" option but logged "resource
# depends on device /dev/mmcblk1p1" three times and then "boot option
# mmcblk1p2#batocera.linux is unresolved". Dropping the colon is what
# Armbian's own (Petitboot-compatible) boot.scr does too. (Hardkernel's own
# real boot.scr for their Ubuntu image, dumped and inspected on real
# hardware, uses "${devnum}:${partition}" and works fine through Petitboot
# there - but that image's boot partition genuinely is GPT #1, same as ours
# now, so the mismatch this avoids may no longer apply either way. Left as
# the already-proven form rather than switched for no benefit.)
#
# VU8M, one config file for every boot path: this script loads config.ini
# via the "ini" command and applies whatever overlays it lists with "fdt
# apply" - the exact mechanism Hardkernel's own official Ubuntu image uses
# (dumped and inspected from a real ODROID-M1 eMMC install: its boot.scr
# does "load ... config.ini && ini generic ${loadaddr}" then, for each name
# in "${overlays}", loads that .dtbo and "fdt apply"s it). Confirmed live
# that this Ubuntu boots correctly with VU8M active through BOTH Petitboot
# and skip_spiboot - unlike the generic uEnv.txt-style "env import -t"
# mechanism 3rd-party OSes like CoreELEC use, which multiple ODROID forum
# users report Petitboot ignoring (t=33873 posts from rpineau and umiki:
# overlays/args set via "env import" in config.ini are dropped when booting
# through Petitboot, but do apply when the card boots itself directly).
# "ini" is a different, Petitboot-supported command, not an alias for that.
# CONFIG_CMD_INI is enabled in this project's own mainline 2026.04 build
# too, so this isn't a Hardkernel-only patch.
#
# This replaced an earlier design that pre-merged VU8M into a second,
# complete DTB (rk3568-odroid-m1-active.dtb) and had the user overwrite that
# file to toggle it - built because FDTOVERLAYS in extlinux.conf only ever
# covered the one boot path capable of reading it, and this was the fallback
# once that was in scope. This ini+fdt-apply mechanism covers all the same
# paths directly, so there's no longer a reason to carry two ~177K DTBs
# instead of one DTB plus the ~3K overlay: to toggle now, edit one line in
# /boot/config.ini and reboot.
#
# One script, not extlinux.conf: distro-boot tries extlinux.conf before
# boot.scr, so keeping both would make skip_spiboot's real U-Boot silently
# read extlinux.conf instead of the config.ini logic above (Petitboot itself
# never looked at extlinux.conf either way). Hardkernel's own Ubuntu image
# ships no extlinux.conf either, for the same reason.
#

setenv bootlabel "batocera.linux"

load ${devtype} ${devnum} ${loadaddr} config.ini && ini generic ${loadaddr}

load ${devtype} ${devnum} ${fdt_addr_r} boot/rk3568-odroid-m1.dtb
fdt addr ${fdt_addr_r}

if test "x${overlays}" != "x"; then
	for overlay in ${overlays}; do
		fdt resize 8192
		load ${devtype} ${devnum} ${loadaddr} boot/overlays/${overlay}.dtbo && fdt apply ${loadaddr}
	done
fi

setenv bootargs "initrd=/boot/initrd.lz4 label=BATOCERA rootwait quiet loglevel=0 console=tty3 console=ttyS2,1500000n8 earlycon=uart8250,mmio32,0xfe660000 pci=nomsi"

load ${devtype} ${devnum} ${kernel_addr_r} boot/linux

load ${devtype} ${devnum} ${ramdisk_addr_r} boot/initrd.lz4

echo "Booting ${bootlabel} from ${devtype} ${devnum}..."

booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
