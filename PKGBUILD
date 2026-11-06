# Repackaging of Anthropic's official Claude Desktop .deb (Linux beta)
pkgname=claude-desktop
pkgver=4.23118.0
pkgrel=1
pkgdesc="Desktop application for Claude.ai (official Anthropic .deb, repackaged)"
arch=('x86_64')
url="https://claude.ai"
license=('custom')
depends=('gtk3' 'libnotify' 'nss' 'xdg-utils' 'at-spi2-core' 'libdrm' 'mesa' 'libxcb'
         'libsecret' 'glib2' 'libxtst' 'util-linux-libs' 'pipewire' 'xdg-desktop-portal' 'alsa-lib')
optdepends=('libayatana-appindicator: tray icon'
            'gnome-keyring: store sign-in (or kwallet on KDE)'
            'bubblewrap: sandboxing' 'socat' 'openssh'
            'qemu-system-x86: Cowork VM' 'edk2-ovmf: Cowork VM' 'virtiofsd: Cowork VM')
options=('!strip' '!debug')
install=claude-desktop.install
source=("claude-desktop_${pkgver}_amd64.deb")
sha256sums=('1ad996e8caab05c9b374646051c40cb6bb9d84f371756f15b8d3728897515a97')
noextract=("claude-desktop_${pkgver}_amd64.deb")

package() {
  bsdtar -xf "$srcdir/claude-desktop_${pkgver}_amd64.deb" -C "$srcdir" data.tar.xz
  bsdtar -xpf "$srcdir/data.tar.xz" -C "$pkgdir"
  rm -rf "$pkgdir/usr/share/lintian"
  chmod 4755 "$pkgdir/usr/lib/claude-desktop/chrome-sandbox"

  # What the Debian postinst would generate, as package-owned files
  local res="$pkgdir/usr/lib/claude-desktop/resources"
  install -Dm644 "$res/gnome-search-provider/com.anthropic.Claude.search-provider.ini" \
    "$pkgdir/usr/share/gnome-shell/search-providers/com.anthropic.Claude.search-provider.ini"
  install -Dm644 "$res/gnome-search-provider/com.anthropic.Claude.SearchProvider.service" \
    "$pkgdir/usr/share/dbus-1/services/com.anthropic.Claude.SearchProvider.service"
  install -Dm644 "$res/linux-mime/com.anthropic.Claude.xml" \
    "$pkgdir/usr/share/mime/packages/com.anthropic.Claude.xml"
  if [ -x "$res/bin/ccd" ]; then
    ln -s ../lib/claude-desktop/resources/bin/ccd "$pkgdir/usr/bin/ccd"
  fi
  install -Dm644 "$pkgdir/usr/share/doc/claude-desktop/copyright" \
    "$pkgdir/usr/share/licenses/claude-desktop/copyright"
}
