################################################################################
#
# cargo-c
#
################################################################################

# Pinned to our fork's odroidm1-rustc1.95-pin branch tip instead of
# upstream v0.10.19 directly: cargo-c ships no Cargo.lock, so buildroot's
# cargo-vendor download step always resolves transitive deps to whatever
# is newest on crates.io at build time. kstring (pulled in via
# toml -> toml_edit) bumped its MSRV to rustc 1.96 in 2.0.3, which breaks
# a fresh vendor against this buildroot's host-rustc (pinned at 1.95.0,
# see buildroot/package/rust/rust.mk) with "rustc 1.95.0 is not supported
# by kstring@2.0.4". Our fork just adds an explicit kstring = "=2.0.2"
# dependency to Cargo.toml so the vendor resolves to an MSRV-1.73
# release instead - see https://github.com/Pyohwan/cargo-c/commit/3ddf1eb
CARGO_C_VERSION = 3ddf1ebbc6fe4df186e5ad7488cdaeaaeaa6e046
CARGO_C_SITE = $(call github,Pyohwan,cargo-c,$(CARGO_C_VERSION))
CARGO_C_LICENSE = MIT License
CARGO_C_LICENSE_FILES = LICENSE

HOST_CARGO_C_DEPENDENCIES = host-pkgconf host-rustc host-openssl

$(eval $(host-cargo-package))
