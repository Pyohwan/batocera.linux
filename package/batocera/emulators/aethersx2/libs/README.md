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

**2026-08-22 addition - `libcurl.so.4` + its transitive closure**: launching
aethersx2 failed immediately with `/usr/lib/libcurl.so.4: no version
information available (required by /usr/aethersx2/aethersx2)`. Our own
buildroot-built libcurl (`package/batocera/.../curl`) has no `.gnu.version_d`
at all (built without versioned-symbols support), while the aethersx2
binary's `.gnu.version_r` hard-requires the `CURL_OPENSSL_4` version node
that only a normally-built (Debian-style) libcurl exports - same class of
problem as the GL/GLX shims above, just one dependency layer deeper. Same
fix: vendor a real Debian aarch64 `libcurl.so.4` (`libcurl4t64` package,
OpenSSL flavour - confirmed via `readelf -V` to define `CURL_OPENSSL_4`),
plus its own `NEEDED` closure that this board doesn't otherwise provide
(nghttp3/idn2/ssh2/gssapi_krb5+krb5+k5crypto+krb5support/ldap+lber/sasl2 -
resolv/keyutils/unistring/com_err/nghttp2/rtmp/psl/ssl/crypto/zstd/brotlidec/z
were all already present on this board and didn't need vendoring). None of
this networking stack is actually exercised at runtime (aethersx2 has no
network feature enabled in this build, same reasoning as `libpcap` above) -
purely a NEEDED-pass satisfaction, not functional network support.

**Follow-up, same session**: fixing the curl load surfaced a second, same-class
mismatch one layer deeper - this board's own `libssl.so.3`/`libcrypto.so.3`
don't export `ENGINE_init` (`undefined symbol: ENGINE_init, version
OPENSSL_3.0.0`), a legacy OpenSSL 1.1-era API some 3.x builds keep and others
(including this board's) drop. Unlike the curl-closure libs above, curl's
TLS backend init genuinely does call into libssl/libcrypto at process
startup (not just a NEEDED-pass formality), so vendored Debian's
`libssl3t64` here too rather than leaving it as a dangling requirement -
`readelf`/`nm` confirmed the Debian build exports `ENGINE_init`. No further
NEEDED gap: `libssl.so.3`/`libcrypto.so.3` only pull in `libz.so.1`/
`libzstd.so.1`, both already present.

Debian package each file's soname maps to (standard Debian/glvnd/mesa/curl
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
| `libcurl.so.4` | `2d9cbabde404c2d61ca71a4ff1ae05e38d69e281bc788ac2a21bb10037061149` | `libcurl4t64` (8.14.1-2+deb13u4, OpenSSL flavour) |
| `libnghttp3.so.9` | `82319f388b327a204047d2de787decbd9f592f81e23984d4a1b166306e69667c` | `libnghttp3-9` |
| `libidn2.so.0` | `6ce57885b9ff21ba3fa902c1c515050230d8d6703f12f9a7d1e3d4e27279966e` | `libidn2-0` |
| `libssh2.so.1` | `bc6e431ac9de9f1778cae68407d4b3a0658445b9ee24a010a6d3b5b3246bc63d` | `libssh2-1t64` |
| `libgssapi_krb5.so.2` | `967b9c108b49481f6cc1358d675a6c1b16754254c84c421c43a5814010e2a215` | `libgssapi-krb5-2` |
| `libkrb5.so.3` | `deb1db5877ee7535d8434003404b4a4e181ab660a9e5370ba66c4b8e759e1111` | `libkrb5-3` |
| `libk5crypto.so.3` | `950c7c9c2da1d5ebaae583a6c4da6b9b41bbbee6a4a8f848a868c0e106fe9335` | `libk5crypto3` |
| `libkrb5support.so.0` | `265157c5541d3cc73f5bb5cf43e8a58e996a25211d716a9ab2ba65b1a787633a` | `libkrb5support0` |
| `libldap.so.2` | `52130bdf6f1abdd8b476193cfd532d8c9f3a6d57eeabe06e4edb65b1711be83c` | `libldap2` |
| `liblber.so.2` | `87376cef9c124257cec7fc0b5eac1b4c8535f597c6ebae70ad9334385cfb14d3` | `libldap2` (bundled) |
| `libsasl2.so.2` | `8bfeedd24d410b345ac39c26dfa9970609fe0ca6738a20fd6ac154a232aec152` | `libsasl2-2` |
| `libssl.so.3` | `0cd0e03cfadce973b7ff323db550794f487f3a7bed3b7f43eb23336e7d466647` | `libssl3t64` (3.5.6-1~deb13u2) |
| `libcrypto.so.3` | `d451f843462c144e74c4f11503d3cc894d775deb10d3cfc129fc3aa70cfe8dda` | `libssl3t64` (bundled) |

All are `aarch64`, stripped, with a BuildID (`readelf -n` / `file <lib>`) if
a byte-for-byte source match against a specific Debian snapshot is ever
needed. The curl-closure files are all from Debian 13 (trixie/stable)
`main/binary-arm64`, fetched 2026-08-22.
