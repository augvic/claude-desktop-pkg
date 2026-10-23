#!/usr/bin/env bash
# Updates Claude Desktop on Arch from Anthropic's official .deb.
#
# Flow: downloads the key and the signed index from the official apt
# repository, verifies the signature (pinned fingerprint), checks the hash
# chain (InRelease -> Packages -> .deb), updates the PKGBUILD, runs makepkg
# and installs with pacman.
#
# Usage: ./update.sh [--force]   (--force rebuilds even if already up to date)
set -euo pipefail

REPO="https://downloads.claude.ai/claude-desktop/apt/stable"
KEY_URL="https://downloads.claude.ai/claude-desktop/key.asc"
FINGERPRINT="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

for cmd in curl gpg sha256sum makepkg pacman awk sed; do
  command -v "$cmd" >/dev/null || die "command '$cmd' not found"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GNUPGHOME="$TMP/gnupg"
mkdir -m 700 "$GNUPGHOME"

# 1. Signing key, checking the fingerprint
info "Downloading signing key..."
curl -fsSL "$KEY_URL" -o "$TMP/key.asc"
gpg --batch --quiet --import "$TMP/key.asc" 2>/dev/null
gpg --batch --with-colons --fingerprint "$FINGERPRINT" >/dev/null 2>&1 \
  || die "the downloaded key does not have the expected fingerprint ($FINGERPRINT)"

# 2. Signed InRelease; only the verified content is used from here on
info "Verifying repository signature..."
curl -fsSL "$REPO/dists/stable/InRelease" -o "$TMP/InRelease"
gpg --batch --status-fd 3 --output "$TMP/Release" --decrypt "$TMP/InRelease" \
  3>"$TMP/status" 2>/dev/null || die "failed to verify InRelease"
grep -q "^\[GNUPG:\] VALIDSIG .* $FINGERPRINT\$" "$TMP/status" \
  || grep -q "^\[GNUPG:\] VALIDSIG $FINGERPRINT " "$TMP/status" \
  || die "InRelease signature is invalid or from another key"

# 3. Packages index, checked against the SHA256 in the verified Release
curl -fsSL "$REPO/dists/stable/main/binary-amd64/Packages" -o "$TMP/Packages"
expected=$(awk '/^SHA256:/{s=1;next} /^[^ ]/{s=0} s && $3=="main/binary-amd64/Packages"{print $1}' "$TMP/Release")
[[ -n "$expected" ]] || die "Packages hash not found in Release"
[[ "$(sha256sum "$TMP/Packages" | cut -d' ' -f1)" == "$expected" ]] \
  || die "Packages hash does not match"

# 4. Latest version and its SHA256
read -r version filename sha < <(awk '
  /^Package: /{p=$2} /^Version: /{v=$2} /^Filename: /{f=$2} /^SHA256: /{h=$2}
  /^$/{ if (p=="claude-desktop") print v, f, h; p=v=f=h="" }
  END{ if (p=="claude-desktop") print v, f, h }' "$TMP/Packages" | sort -V -k1,1 | tail -n1)
[[ -n "${version:-}" && -n "${sha:-}" ]] || die "could not find the package in the index"
[[ "$version" =~ ^[0-9][0-9.]*$ ]] || die "unexpected version: $version"

installed=$(pacman -Q claude-desktop 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//' || true)
info "Installed: ${installed:-none} | Available: $version"
if [[ "$installed" == "$version" && $FORCE -eq 0 ]]; then
  info "Already up to date. Use --force to reinstall."
  exit 0
fi

# 5. Download the .deb and check its hash
deb="claude-desktop_${version}_amd64.deb"
if [[ ! -f "$DIR/$deb" ]] || [[ "$(sha256sum "$DIR/$deb" | cut -d' ' -f1)" != "$sha" ]]; then
  info "Downloading $deb..."
  curl -fL "$REPO/$filename" -o "$TMP/$deb"
  [[ "$(sha256sum "$TMP/$deb" | cut -d' ' -f1)" == "$sha" ]] || die ".deb hash does not match"
  mv "$TMP/$deb" "$DIR/$deb"
fi
info ".deb SHA256 verified."

# 6. Update the PKGBUILD and build
cd "$DIR"
sed -i -e "s/^pkgver=.*/pkgver=$version/" \
       -e "s/^pkgrel=.*/pkgrel=1/" \
       -e "s/^sha256sums=.*/sha256sums=('$sha')/" PKGBUILD
info "Building the package..."
makepkg -f --cleanbuild
rm -rf "$DIR/src" "$DIR/pkg"

pkgfile="$DIR/claude-desktop-${version}-1-x86_64.pkg.tar.zst"
[[ -f "$pkgfile" ]] || die "package was not built"

# 7. Install (sudo needs an interactive terminal to ask for the password)
if [[ ! -t 0 ]] && ! sudo -n true 2>/dev/null; then
  info "Package built, but there is no terminal to ask for the sudo password."
  info "Install it from a terminal with: sudo pacman -U $pkgfile"
  exit 0
fi
info "Installing (sudo will ask for your password)..."
sudo pacman -U "$pkgfile"

# 8. Remove .deb files and packages from older versions
find "$DIR" -maxdepth 1 \( -name 'claude-desktop_*_amd64.deb' ! -name "$deb" \
  -o -name 'claude-desktop-*-x86_64.pkg.tar.zst' ! -name "${pkgfile##*/}" \) -print -delete

info "Done: Claude Desktop $version installed."
