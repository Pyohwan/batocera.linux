################################################################################
#
# vulkan-wsi-layer
#
################################################################################
# ARM's open-source Vulkan layer implementing VK_KHR_wayland_surface (and
# other WSI backends) on top of an ICD that doesn't provide its own -
# confirmed live that the g29p1 blob's Vulkan ICD only exports VK_KHR_display
# (bare DRM, no compositor) among windowing-system extensions: no
# VK_KHR_wayland_surface, so no Vulkan app can create a surface for a
# Wayland window without this layer sitting in front of it (SDL2/PPSSPP's
# own Vulkan surface/device creation otherwise fails outright even though
# vulkaninfo enumerates the GPU fine - confirmed live, this is a real ICD
# capability gap, not a downstream packaging/config bug). Same technique
# ROCKNIX uses for the same blob/board family (RK3566/g29p1), version pin
# and build flags below mirror their package.mk 1:1 (projects/ROCKNIX/
# packages/graphics/vulkan-wsi-layer/package.mk).
VULKAN_WSI_LAYER_VERSION = 8f077c5c862e5259841d524de8280b8c2429990a
VULKAN_WSI_LAYER_SITE = https://gitlab.freedesktop.org/mesa/vulkan-wsi-layer.git
VULKAN_WSI_LAYER_SITE_METHOD = git
VULKAN_WSI_LAYER_LICENSE = MIT
VULKAN_WSI_LAYER_LICENSE_FILES = LICENSE

VULKAN_WSI_LAYER_DEPENDENCIES = libdrm wayland-protocols vulkan-loader vulkan-headers linux

# BUILD_WSI_WAYLAND/DISPLAY require an external DMA allocator - dma_buf_heaps
# is what ROCKNIX uses for every non-RK3588 (BSP-kernel) device, matching
# this board (BSP 6.1, not mainline).
#
# WSIALLOC_MEMORY_HEAP_NAME: ROCKNIX's non-RK3588 value is "linux,cma", but
# that heap doesn't exist on this BSP 6.1 kernel - confirmed live, this
# board's /dev/dma_heap/ only has "reserved", "system", "system-uncached"
# (a different DMA-heap exporter/naming scheme than whatever ROCKNIX's own
# kernel registers under "linux,cma"). "system" is the generic CMA-backed
# general-purpose heap here.
VULKAN_WSI_LAYER_DMA_HEAP = system
#
# KERNEL_HEADER_DIR needs the *configured* kernel source tree (drm_utils
# includes kernel DRM/fourcc headers directly, not the installed userspace
# uapi headers) - $(LINUX_DIR) is buildroot's own extracted+configured
# linux package dir, already built by the time this package builds since
# it's declared as a dependency above.
VULKAN_WSI_LAYER_CONF_OPTS = \
	-DVULKAN_CXX_INCLUDE=$(STAGING_DIR)/usr/include \
	-DBUILD_WSI_HEADLESS=OFF \
	-DBUILD_WSI_WAYLAND=ON \
	-DSELECT_EXTERNAL_ALLOCATOR=dma_buf_heaps \
	-DWSIALLOC_MEMORY_HEAP_NAME=$(VULKAN_WSI_LAYER_DMA_HEAP) \
	-DENABLE_WAYLAND_FIFO_PRESENTATION_THREAD=ON \
	-DKERNEL_HEADER_DIR=$(LINUX_DIR)/arch/arm64/include \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5

# Installed as an implicit layer (auto-activates for every Vulkan app, no
# VK_INSTANCE_LAYERS needed) - same mechanism this board's MangoHud Vulkan
# overlay already uses (/usr/share/vulkan/implicit_layer.d/).
#
# Both files go in the SAME directory: the upstream manifest's
# "library_path" is the relative "./libVkLayer_window_system_integration.so"
# (confirmed in layer/VkLayer_window_system_integration.json), and the
# Khronos loader resolves a relative library_path against the directory
# containing the *manifest*, not against /usr/lib or any library search
# path. ROCKNIX's own package.mk installs the .so to /usr/lib/ and the
# .json to implicit_layer.d/ separately - do not copy that split, it would
# leave the relative path unresolvable here (untested whether that split
# actually works for them; not worth the risk when co-locating is simpler
# and unambiguously correct per the loader's own documented resolution
# rule).
define VULKAN_WSI_LAYER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/libVkLayer_window_system_integration.so \
		$(TARGET_DIR)/usr/share/vulkan/implicit_layer.d/libVkLayer_window_system_integration.so
	$(INSTALL) -D -m 0644 $(@D)/VkLayer_window_system_integration.json \
		$(TARGET_DIR)/usr/share/vulkan/implicit_layer.d/VkLayer_window_system_integration.json
endef

$(eval $(cmake-package))
