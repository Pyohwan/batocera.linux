# Vendored shim libs

Pulled from a real, working Debian aarch64 install and live-tested on this
board (see `project_odroid_retro.md`, 2026-08-16, AetherSX2 section) rather
than built from source or fetched fresh at build time, to guarantee they
match what was actually verified working. Installed to
`/usr/aethersx2/libs/` (not the system `/usr/lib/`) and only pulled in via
`aethersx2Generator.py`'s `LD_LIBRARY_PATH=/usr/aethersx2/libs:/usr/lib` -
they never shadow the system's own copies for any other process.

The `aethersx2` binary link-time-depends on all of these (`NEEDED` entries),
but only the GL/GLX/GLdispatch/OpenGL ones are ever actually called:
`Renderer` is forced to Vulkan in the generator, so real GLX rendering is
never invoked - these four exist purely to satisfy the dynamic linker's
NEEDED pass at process startup. `libpcap` is genuinely unused at runtime
(AetherSX2 has no networking feature enabled in this build) and is only
here for the same NEEDED-pass reason; because it precedes `/usr/lib` in
`LD_LIBRARY_PATH`, it does shadow this board's real `libpcap`
(`BR2_PACKAGE_LIBPCAP`, a newer ABI) for the aethersx2 process specifically
- confirmed intentional, not a conflict, since it's never called.

Debian package each file's soname maps to (standard Debian/glvnd/mesa
packaging, not independently re-verified against a specific snapshot -
the sha256 below is the actual reproducibility anchor):

| File | sha256 | Debian package (soname convention) |
| --- | --- | --- |
| `libGL.so.1` | `900229e312e1a5bc67cffdbf89da8e928a8b22713f184154ca7174d457267763` | `libglvnd0` |
| `libGLX.so.0` | `78927ffde410c5a569319c231cc0b8a534aecf781bb3c628e482957c1cf91b83` | `libglvnd0` |
| `libGLdispatch.so.0` | `912ba2ff2d3aa73e6bd579877a462f9541d5d1df4bb9f67435ee4ef16a0f5caa` | `libglvnd0` |
| `libOpenGL.so.0` | `ef81dc02955b9b44f23d83d4c15ed74d26ca74d0489723b6dda3634422018679` | `libglvnd0` |
| `libGLX_mesa.so.0` | `636c5a39b4d3d91cc00a20215f02fea085ea04ba606f42e2f63f7ee24ad8389e` | `libgl1-mesa-dri` / `mesa-libgl` |
| `libpcap.so.0.8` | `697a7f15f258c96aa0e29945507d1cfeb26dd156991a2967bd0ac7761803156f` | `libpcap0.8` |

All six are `aarch64`, stripped, with a BuildID (`readelf -n` /
`file <lib>`) if a byte-for-byte source match against a specific Debian
snapshot is ever needed.
