#!/usr/bin/env python3
"""usage: ft-stats.py <csv> [--ms] [--warmup 60]

Computes Avg FPS and 1% Low from a frametime log produced by the
FRAMETIME_LOG / FRAMETIME_LOG_VK loggers patched into sdl2, retroarch,
vulkan-wsi-layer, and melonds on this board's Track C image.

  csv   1 column = usec timestamps (SDL2 / vulkan-wsi-layer loggers)
        2 columns = usec timestamp, dupe flag (RetroArch logger)
  --ms  Dolphin's built-in "Log Render Time to File" mode: each row is a
        per-frame duration in milliseconds instead of a timestamp.

All fps figures are computed in the frametime domain (mean of frametimes,
then inverted) rather than by averaging instantaneous fps values, to avoid
harmonic-mean distortion.
"""
import sys
import argparse
import numpy as np


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv")
    ap.add_argument("--ms", action="store_true", help="Dolphin per-frame ms log")
    ap.add_argument("--warmup", type=float, default=60.0,
                     help="seconds to discard from the start (shader/pipeline warmup)")
    args = ap.parse_args()

    raw = np.genfromtxt(args.csv, delimiter=",")
    if raw.ndim == 1:
        raw = raw[:, None]

    if args.ms:
        # Dolphin: each row = frametime in ms
        ft = raw[:, 0] / 1000.0
        t = np.cumsum(ft)
    else:
        # usec timestamps; frametime = diff between consecutive presents
        t = raw[:, 0] / 1e6
        ft = np.diff(t)
        t = t[1:] - t[0]

    keep = t > args.warmup
    ft = ft[keep]
    n = len(ft)
    if n < 2:
        sys.exit(f"error: only {n} frames after warmup cutoff ({args.warmup}s) - log too short or bad file")

    if raw.shape[1] > 1 and not args.ms:
        # RetroArch dupe-flag column: separate "real" (non-duped) render rate
        real = raw[1:, 1][keep].astype(bool)
        print(f"코어 실제 렌더 fps  : {real.sum() / ft.sum():6.1f}  (dupe 제외)")

    s = np.sort(ft)[::-1]  # slowest first
    low1 = s[:max(1, n // 100)]
    low01 = s[:max(1, n // 1000)]

    print(f"프레임 수           : {n}  ({ft.sum():.0f}s)")
    print(f"Avg FPS             : {n / ft.sum():6.1f}")
    print(f"1% Low              : {1 / low1.mean():6.1f}")
    print(f"p99                 : {1 / np.percentile(ft, 99):6.1f}")
    print(f"0.1% Low (참고)     : {1 / low01.mean():6.1f}")


if __name__ == "__main__":
    main()
