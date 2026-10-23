# 🤖 claude-desktop-pkg

📦 Packages **Claude Desktop** for 🐧 **Arch Linux** from Anthropic's official `.deb`
(Linux beta, published at `downloads.claude.ai`).

> ⚠️ Arch is not officially supported by Anthropic: the app targets Debian/Ubuntu.
> This PKGBUILD only repackages the official binaries, without modifying them.

## 🚀 Usage

```bash
./update.sh
```

The script:

1. 🔑 downloads the signing key and checks the fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`;
2. ✍️ verifies the signature of the official apt repository's `InRelease`;
3. 🔗 checks the hash chain (`InRelease` → `Packages` → `.deb`);
4. 📝 updates `pkgver` and `sha256sums` in the `PKGBUILD`;
5. 🛠️ runs `makepkg` and installs with `sudo pacman -U`.

✅ If you are already on the latest version, it does nothing (use `--force` to rebuild).

💡 Run it from an interactive terminal, since `sudo` needs to ask for your password.

## 📁 Files

- 📄 `PKGBUILD`: extracts the `.deb` and installs its files, reproducing what the Debian
  `postinst` would do (GNOME search provider, MIME types, `ccd` link), without the apt
  repository and the AppArmor profile.
- 💬 `claude-desktop.install`: post-install message.
- 🔄 `update.sh`: verified download, build and install.

## 🖥️ Cowork (optional)

```bash
sudo pacman -S qemu-system-x86 edk2-ovmf virtiofsd
```

```bash
sudo usermod -aG kvm $USER
```

🔁 Then log out and back in.

## 🗑️ Uninstall

```bash
sudo pacman -R claude-desktop
```
