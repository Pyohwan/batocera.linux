################################################################################
#
# aethersx2
#
################################################################################
# Prebuilt aarch64 ELF binary (not an AppImage, despite the ROCKNIX package
# description calling it one - confirmed via \x7fELF magic bytes), vendored
# as-is from ROCKNIX. Vanilla PCSX2/bmdhacks-derived GS renderers hit a real
# Mali G52 GPU hardware fault (DATA_INVALID_FAULT, job status 0x58) a few
# seconds to a couple minutes into real gameplay on this exact g29p1 blob +
# vendor kbase g25p0 combination (see project_odroid_retro.md, 2026-08-16,
# for the full gdb/dmesg debugging writeup). AetherSX2 ships an older GS
# renderer branch (Tahlreth's Android-era Adreno/Mali-hardened command
# patterns) that does not hit it - live smoke-tested on this board for 5+
# minutes of actual gameplay with zero GPU faults where bmdhacks/pcsx2
# reliably faults within ~100s. This package exists purely to make that
# already-proven-working binary launchable from ES.
# Pinned to a specific commit rather than the branch HEAD, same as the
# mali-g52-odroidm1 blob below - "main" is a moving target, and this is a
# third-party prebuilt binary with no upstream release/tag to pin to
# instead, so a hash check (aethersx2.hash) matters even more here than
# for source packages we actually compile ourselves.
AETHERSX2_VERSION = 1.5-3606
AETHERSX2_SOURCE = aethersx2.tar.gz
AETHERSX2_SITE = https://github.com/ROCKNIX/packages/raw/0b61d2a472751b127b1806207d9c459c7d6e334d
AETHERSX2_LICENSE = LGPL
AETHERSX2_EMULATOR_INFO = aethersx2.emulator.yml

define AETHERSX2_EXTRACT_CMDS
	mkdir -p $(@D)
	$(TAR) xf $(AETHERSX2_DL_DIR)/$(AETHERSX2_SOURCE) -C $(@D) --strip-components=1
endef

define AETHERSX2_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/aethersx2/libs
	cp -pr $(@D)/usr/share/* $(TARGET_DIR)/usr/aethersx2/
	chmod 755 $(TARGET_DIR)/usr/aethersx2/aethersx2
	# Mesa/GLVND shim libs (libGLX/libOpenGL/libGLdispatch/libGLX_mesa)
	# plus an older-ABI libpcap that the binary link-time-depends on but
	# never actually calls at runtime here - Renderer is forced to
	# Vulkan=14 in the configgen generator, so real GLX is never invoked;
	# these only satisfy the dynamic linker's NEEDED-library pass. Pulled
	# from a real, working Debian aarch64 install and live-tested on this
	# exact board first rather than built from source or fetched fresh at
	# build time, to guarantee they match what was actually verified
	# working (see project_odroid_retro.md 2026-08-16 AetherSX2 section).
	cp -p $(AETHERSX2_PKGDIR)/libs/*.so.* $(TARGET_DIR)/usr/aethersx2/libs/
endef

$(eval $(generic-package))
$(eval $(emulator-info-package))
