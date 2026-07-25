#
# flash-kernel: bootscr.odroid-rk356x
#
# Compiled to boot.scr at build time (see create-boot-script.sh) and
# shipped on the boot partition. This is NOT used by our own boot chain -
# mainline U-Boot boots this board via /extlinux/extlinux.conf instead
# (confirmed by UART: boot.scr is never sourced). Its only purpose is to
# be found and parsed by the on-board SPI-NOR Petitboot, whose own parser
# (pb-discover -> uboot-parser) understands U-Boot boot scripts and
# grub.cfg but explicitly NOT extlinux.conf - per the ODROID-M1 Petitboot
# author's own answer on the ODROID forum (thread t=44346: "extlinux.conf
# is not supported by Petitboot, you need to add boot.scr"). That is what
# makes this SD card show up as a boot option in the Petitboot menu at
# all; without it Petitboot mounts and scans our boot partition and finds
# nothing.
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
# Armbian's own (Petitboot-compatible) boot.scr does too.
#
# VU8M note: Petitboot boots via kexec and has no equivalent of
# extlinux.conf's FDTOVERLAYS, so this entry always uses the plain base
# DTB - i.e. booting through the Petitboot menu is always HDMI-only. The
# VU8M toggle (extlinux.conf's DEFAULT line) applies to direct SD boot,
# which is the normal path anyway.
#

setenv bootlabel "batocera.linux"

setenv bootargs "initrd=/boot/initrd.lz4 label=BATOCERA rootwait quiet loglevel=0 console=tty3 console=ttyS2,1500000n8 earlycon=uart8250,mmio32,0xfe660000 pci=nomsi"

load ${devtype} ${devnum} ${fdt_addr_r} boot/rk3568-odroid-m1.dtb
fdt addr ${fdt_addr_r}

load ${devtype} ${devnum} ${kernel_addr_r} boot/linux

load ${devtype} ${devnum} ${ramdisk_addr_r} boot/initrd.lz4

echo "Booting ${bootlabel} from ${devtype} ${devnum}..."

booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
