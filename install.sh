#!/usr/bin/env bash
# T-Echo Card Passkey installer: downloads the upstream projects and libraries, applies the
# patches from this repository, and builds the UF2 files into dist/.
#
# Nothing third-party is stored in this repository. Everything below is downloaded from its
# official source at a pinned version and, for binary files, checked against a SHA-256 hash.
# By running this script you obtain those components directly from their authors, under their
# own licenses.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
WORK=$ROOT/work
DIST=$ROOT/dist

OPENSK_REPO=https://github.com/google/OpenSK.git
OPENSK_COMMIT=f53621c33a02eee001cae82a87aa719fca61565b   # pins wasefire 1e46740ed6fe9b9900606454928bd3ae8c11cc7e
NRFXLIB_COMMIT=529012899ffb2aa8ef69cbbb315eaf2848737aca
NRFXLIB_RAW=https://raw.githubusercontent.com/nrfconnect/sdk-nrfxlib/$NRFXLIB_COMMIT/nfc
P256_CRATE=https://static.crates.io/crates/p256-cortex-m4-sys/p256-cortex-m4-sys-0.1.0.crate
P256_SHA=54a73da4b90c4bb139ff5cca5526f796451cfeea58f5915bc739df36803977de

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "'$1' is required. $2"; }

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
fetch() { # url dest sha256
  curl -fsSL "$1" -o "$2" || die "download failed: $1"
  [ "$(sha256 "$2")" = "$3" ] || die "checksum mismatch for $2 (from $1)"
}

need git "Install git."
need curl "Install curl."
need python3 "Install Python 3."
need clang "Install clang (macOS: xcode-select --install, Linux: your distribution's clang package)."
need rustup "Install Rust from https://rustup.rs and open a new terminal."

say "Downloading OpenSK and Wasefire (pinned versions)"
if [ ! -d "$WORK/OpenSK/.git" ]; then
  mkdir -p "$WORK"
  git clone -q "$OPENSK_REPO" "$WORK/OpenSK"
  git -C "$WORK/OpenSK" -c advice.detachedHead=false checkout -q "$OPENSK_COMMIT"
  git -C "$WORK/OpenSK" submodule update -q --init third_party/wasefire
  say "Applying the T-Echo Card patches"
  git -C "$WORK/OpenSK" apply "$ROOT/patches/opensk.patch"
  git -C "$WORK/OpenSK/third_party/wasefire" apply "$ROOT/patches/wasefire.patch"
else
  echo "work/OpenSK already exists (delete the work/ folder to start over)"
fi
W=$WORK/OpenSK/third_party/wasefire
NFC=$W/crates/runner-nordic/crates/nrf-nfc/vendor
P256=$W/crates/runner-nordic/crates/p256-cm4/vendor

say "Installing the pinned Rust toolchain (first time only, can take a few minutes)"
(cd "$W" && rustup toolchain install >/dev/null)
(cd "$WORK/OpenSK" && rustup toolchain install >/dev/null)

say "Downloading Nordic's NFC Type 4 Tag library (Nordic license, for Nordic chips only)"
mkdir -p "$NFC/lib" "$NFC/include"
fetch "$NRFXLIB_RAW/lib/cortex-m4/soft-float/libnfc_t4t.a" "$NFC/lib/libnfc_t4t.a" fa22a26f5149583fdeb2feba1978112312062fa510ec587cea9a62625ac5eb5e
fetch "$NRFXLIB_RAW/include/nfc_t4t_lib.h" "$NFC/include/nfc_t4t_lib.h" 8495179491dc8f041c88a0ece467ff19587b1a7f19091ef38e972bb1e8b06343
fetch "$NRFXLIB_RAW/include/nrf_nfc_errno.h" "$NFC/include/nrf_nfc_errno.h" 0199ae961309e5b98df501f6e3a2e712d6d0e65dbe80194cbaa7788f2b20f156
fetch "$NRFXLIB_RAW/license.txt" "$NFC/license.txt" 2c11c1db1d53fd9e4c0b5b9064a7ed4f8d56c19ff77bd10ab2b07352ee68cad8

say "Building Nordic's nrfx NFCT driver (downloads nrfx v4.2.1 and CMSIS)"
(cd "$W" && "$NFC/nrfx-build/build-nrfx.sh")

say "Downloading and building P256-Cortex-M4 (fast P-256 crypto)"
TMP=$(mktemp -d)
fetch "$P256_CRATE" "$TMP/p256.crate" "$P256_SHA"
tar -xzf "$TMP/p256.crate" -C "$TMP"
for f in p256-cortex-m4.c p256-cortex-m4.h p256-cortex-m4-config.h p256-cortex-m4-asm-gcc.S LICENSE.txt; do
  cp "$TMP/p256-cortex-m4-sys-0.1.0/P256-Cortex-M4/$f" "$P256/$f"
done
rm -rf "$TMP"
(cd "$W" && "$P256/build.sh")

say "Building the firmware (first build takes a while)"
(cd "$WORK/OpenSK" && ./flash.sh nrf52840_techo < /dev/null)

say "Creating the UF2 files"
HEX=$W/target/wasefire/platform.hex
[ -f "$HEX" ] || die "build did not produce $HEX"
mkdir -p "$DIST"
python3 "$WORK/OpenSK/tools/techo_uf2.py" --wipe-store "$HEX" "$DIST/techo-passkey-first-install.uf2"
python3 "$WORK/OpenSK/tools/techo_uf2.py" "$HEX" "$DIST/techo-passkey-update.uf2"

say "Done"
echo "  dist/techo-passkey-first-install.uf2  first install only: ERASES the key storage"
echo "  dist/techo-passkey-update.uf2         every later update: keeps your passkeys and PIN"
