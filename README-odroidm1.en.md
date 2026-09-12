# ODROID-M1 (bsp-odroidm1)

*English | [한국어](README-odroidm1.ko.md)*

## Features added on top of vanilla Batocera

- Uses Hardkernel's own BSP kernel (**Linux 6.1.141**) instead of mainline
  - Required for VU8M, mono audio, and USB3.0 support
- VU8M (Hardkernel's 8" DSI touchscreen) support
- Uses the vendor Mali G52 blob (g29p1 generation) - GLES + Vulkan
- Wayland (labwc) compositor support - enables standalone Qt-based emulators (PCSX2/Dolphin/AetherSX2, etc.) to actually run
- Fixed mono speaker volume/output routing (default volume was far too quiet)
- FBNeo Korean-patched core (`fbneo_korean`) set as default - includes DsNo's patch, which fixes a CRC32 mismatch that caused Korean-patched ROMs to be rejected
- AetherSX2 (PS2) set as default - an alternative core that avoids a Mali GPU fault that mainline PCSX2-family cores hit
- Vulkan rendering support for PS2/GameCube/Dreamcast/PSP and other major systems
- Re-tuned per-system "auto" core/API defaults to match actual measured best performance

## Setup

### Display (HDMI / VU8M)

- **HDMI**: enabled by default, no configuration needed (tested up to 1080p).
- **VU8M**: disabled by default. Enable it in `config.ini` on the **BATOCERA** partition (the drive that shows up when you plug the SD card into a PC):
  ```
  overlays="display_vu8m"
  ```
  Set it back to `overlays=""` to disable. The DSI panel has no hotplug detection, so once the overlay is enabled it's always reported as "connected" whether the panel is physically attached or not - turn it off when not in use.

### Backglass / screen rotation

Everything below assumes VU8M is already enabled via `overlays="display_vu8m"` in `config.ini` above.

**Note**: the settings below are stored in `system/batocera.conf`, which only exists after the board has **booted at least once** and initialized the SHARE partition - a freshly flashed SD card has neither this file nor the `system` folder at all (Batocera creates the whole default directory structure - `roms`/`bios`/`saves`/`system`, etc. - on first boot). Do this after the first boot.

**Using it as a backglass**: to use VU8M as a secondary screen showing box art/game info while playing on the main screen (HDMI), go to **MAIN MENU → SYSTEM SETTINGS → HARDWARE → MULTISCREENS → BACKGLASS / INFORMATION SCREEN** and set VIDEO OUTPUT to VU8M (`DSI-1`). **This must be set** for ES to actually configure that output (resolution/rotation) - leaving it blank just gets you an unused extended screen tacked onto HDMI with nothing rendered on it.

**Exception - NDS dual-screen**: NDS naturally has two screens (top/bottom). Enabling both HDMI and VU8M together with the `melonDS` core lets you output NDS's top and bottom screens to the two physical displays separately. However, melonDS performs poorly on this board (much slower than the default `drastic` core even with GPU acceleration on), making it **impractical for regular use** - stick with the default `drastic` (single screen) unless you specifically need the dual-screen setup.

**Rotation**: best done from the ES menu - note that both options are labeled "SCREEN ROTATION", so you have to go by location:
- **MAIN MENU → SYSTEM SETTINGS → HARDWARE → SCREEN ROTATION**: rotates the main screen (HDMI).
- **MAIN MENU → SYSTEM SETTINGS → HARDWARE → MULTISCREENS → BACKGLASS / INFORMATION SCREEN → SCREEN ROTATION**: rotates VU8M (the backglass). (Saved together with the VIDEO OUTPUT setting above.)

These values are stored in `system/batocera.conf` on the **SHARE partition** (the second drive that shows up when you plug the SD card into a PC). Mount that partition and edit the file directly, or over SSH:
```
batocera-settings-set global.videooutput2 DSI-1   # assign VU8M as the 2nd screen (backglass)
batocera-settings-set display.rotate2.DSI-1 3      # rotation value for that screen
```
A **reboot** is needed for this to take effect (EmulationStation only sets up outputs/rotation at startup):
```
reboot
```
Main-screen rotation uses `display.rotate.<connector-name>=<N>` per connector (e.g. `display.rotate.HDMI-A-1`), falling back to the global `display.rotate=<N>` if unset. `<N>` is `0` (normal), `1` (90°), `2` (180°), `3` (270°) - main-screen rotation is also automatically picked up by the boot splash on the next reboot (vanilla mechanism, no extra setup needed). `display.rotate2` (backglass) doesn't apply here - the splash never draws anything to the 2nd screen.

## Per-system performance results and recommended core/API

Measured on **`batocera44-odroidm1-v1.0.0`** (this doc always tracks the latest version - re-verify if the relevant core/kernel/blob changes in a later release), Power Mode fixed to High Performance, Avg FPS / 1% low (frametime-based, an industry-standard metric). **The core/API actually selected by "auto" is bolded.**

| System | Game | Core | API | Avg FPS | 1% Low |
| --- | --- | --- | --- | --- | --- |
| Genesis/Mega Drive | Altered Beast | **genesisplusgx** | — | **60.0** | 50.3 |
| | | genesisplusgx-expanded | — | 60.0 | 47.6 |
| | | picodrive | — | 60.0 | 48.5 |
| FBNeo | Ninja Baseball Bat Man | **fbneo_korean** | — | **60.0** | 41.0 |
| Saturn | Strikers 1945 | **yabasanshiro** | GLES | **59.3** | 24.3 |
| | | beetle-saturn | GLES | 22.5 | 16.8 |
| | | beetle-saturn | Vulkan | 22.8 | 16.4 |
| PSX | Soul Blade | **pcsx_rearmed** | GLES | **60.0** | 38.9 |
| | | pcsx_rearmed | Vulkan | 60.0 | 42.0 |
| | | swanstation | GLES | 58.5 | 32.1 |
| | | swanstation | Vulkan | 59.3 | 34.5 |
| | | mednafen_psx | GLES | 29.0 | 19.6 |
| | | mednafen_psx | Vulkan | 31.3 | 20.7 |
| N64 | Yoshi's Story | standalone mupen64plus(**rice**) | GLES | **59.6** | 30.3 |
| | | standalone mupen64plus(glide64mk2) | GLES | 54.9 | 13.0 |
| | | standalone mupen64plus(gliden64) | GLES | 10.3 | 3.6 |
| | | libretro mupen64plus-next | GLES | 59.5 | 24.5 |
| | | libretro parallel_n64 | GLES | 56.2 | 17.9 |
| Dreamcast | Soulcalibur | **standalone flycast** | **Vulkan** | **55.5** | 11.7 |
| | | standalone flycast | GLES | 56.4 | 13.0 |
| | | libretro flycast | GLES | 55.9 | 10.1 |
| | | libretro flycast | Vulkan | 56.0 | 13.1 |
| PS2 | 2002 FIFA World Cup (Korea) | **AetherSX2** | **Vulkan** | **23.8** | 4.2 |
| GameCube | Pikmin | **standalone Dolphin** | **Vulkan** | **29.7** | 8.4 |
| PSP | Tekken 6 | **standalone PPSSPP** | **Vulkan** | **58.9** | 27.0 |
| | | standalone PPSSPP | GLES | 54.0 | 17.7 |
| | | libretro ppsspp | GLES | 54.2 | 16.1 |
| | | libretro ppsspp | Vulkan | 54.1 | 27.0 |
| NDS | (excluded from the matrix - all 3 tracks cleared 60fps with 99%+ headroom, so a full sweep wasn't needed) | **drastic** | — | — | — |

**Notes**:
- Genesis/FBNeo use software 2D rendering, so the GLES/Vulkan API distinction doesn't apply.
- The libretro Vulkan cores for N64/Dreamcast (mupen64plus-next, parallel_n64) have a known issue where audio plays but no video appears, so they're excluded above (GLES-only comparison).
- Wii isn't benchmarked separately but is expected to behave the same as GameCube (standalone Dolphin + Vulkan), so the same recommendation applies.

## Known limitations

- **PS2 `pcsx2` core** (mainline PCSX2 family): the newer GS command patterns these cores use trigger a genuine Mali G52 GPU hardware fault (`DATA_INVALID_FAULT`) - confirmed via dmesg logs and actual game hangs. AetherSX2 (a PCSX2-family fork using older GS command patterns) avoids this fault and is used as the default. `pcsx2` is left installed and selectable in EmulationStation for anyone who wants to experiment with it.
