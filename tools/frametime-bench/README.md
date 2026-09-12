# Frametime-based fps benchmarking (Track C)

Replaces eyeballed on-screen fps counters with real frametime logging + the
industry-standard Avg FPS / 1% Low metrics. Deliberately avoids generic
hooking (mangohud-style EGL interposers previously crashed this board's
blob driver) - each logger is a small source patch at a single, specific
per-frame entry point.

## Hook points (4 total)

| # | Location | Covers |
|---|----------|--------|
| 1 | `SDL_EGL_SwapBuffers()` in sdl2 (`board/batocera/patches/sdl2/sdl2_frametime_log.patch`) | standalone SDL2 apps: flycast, mupen64plus, PPSSPP standalone |
| 2 | `video_driver_frame()` in retroarch (`package/batocera/emulators/retroarch/retroarch/900-frametime-log.patch`) | all libretro cores (GLES/GL) |
| 3 | `wsi_layer_vkQueuePresentKHR()` in vulkan-wsi-layer (`package/batocera/gpu/vulkan/vulkan-wsi-layer/0003-frametime-log.patch`) | every Vulkan present on this board (standalone or libretro), incl. AetherSX2 (config-forced Vulkan, no source patch needed) |
| 4 | `ScreenPanelGL::drawScreenGL()` swap in melonds (`package/batocera/emulators/melonds/005-frametime-log.patch`) | melonDS OpenGL Classic renderer (Qt-based, not covered by #1 or #3) |

Not covered, and not fixable the same way:
- **drastic** - closed-source binary. NDS is already concluded (drastic
  90-100%, melonDS the only dual-screen option) - use its built-in Show
  Speed OSD if a number is ever needed.
- **Dolphin standalone** - use its own built-in
  `Graphics > Advanced > "Log Render Time to File"` instead (per-frame ms
  file, read with `--ms` below). Renderer-agnostic, no patch needed.
- **pcsx2-qt (non-AetherSX2 PS2 core)** - already out of the matrix due to
  the GPU DATA_INVALID_FAULT issue; not worth instrumenting.

Loggers are no-ops (single env-var check) when `FRAMETIME_LOG` /
`FRAMETIME_LOG_VK` aren't set, so they can stay in every Track C image
permanently.

## Env vars

- `FRAMETIME_LOG=<path>` - hooks 1, 2, 4 (SDL2 / RetroArch / melonDS)
- `FRAMETIME_LOG_VK=<path>` - hook 3 (vulkan-wsi-layer)

Use **both** at once for RetroArch-with-Vulkan cores (2 and 3 both fire);
treat the wsi-layer file as the source of truth since it captures the
actual present, matching PresentMon/standard-tool semantics.

## Running a measurement

```
FRAMETIME_LOG=/userdata/ft-C-psp-tekken6-run1.csv emulatorlauncher ...
```

(same SSH manual-launch pattern already used for the fps matrix - pull
`WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR`/`LANG` from the live ES/labwc process
env before launching.)

3-5 minutes per run. Start from the same savestate/point across A/B/C.
Keep VU8M off (HDMI only) unless the dual-screen case itself is what's
being measured.

## Analysis

```
scp root@<device>:/userdata/ft-C-psp-tekken6-run1.csv .
python3 tools/frametime-bench/ft-stats.py ft-C-psp-tekken6-run1.csv
```

Dolphin's built-in log:

```
python3 tools/frametime-bench/ft-stats.py dolphin_render_times.txt --ms
```

Output: frame count, Avg FPS, 1% Low, p99, 0.1% Low (reference only - a
3-5 min run only has ~10-20 samples in the slowest 0.1%). For RetroArch
2-column logs, a "코어 실제 렌더 fps" line is also printed, separating
out duped/no-new-frame calls from genuine core-rendered frames.
