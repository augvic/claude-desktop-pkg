# claude-desktop-pkg

Empacota o Claude Desktop para Arch Linux a partir do `.deb` oficial da Anthropic
(Linux beta, publicado em `downloads.claude.ai`).

O Arch não é oficialmente suportado pela Anthropic: o app é feito para Debian/Ubuntu.
Este PKGBUILD apenas reempacota os binários oficiais, sem alterá-los.

## Uso

```bash
./atualizar.sh
```

O script:

1. baixa a chave de assinatura e confere o fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`;
2. verifica a assinatura do `InRelease` do repositório apt oficial;
3. confere os hashes em cadeia (`InRelease` → `Packages` → `.deb`);
4. atualiza `pkgver` e `sha256sums` no `PKGBUILD`;
5. roda `makepkg` e instala com `sudo pacman -U`.

Se já estiver na versão mais recente, não faz nada (use `--force` para reconstruir).
Rode num terminal interativo, pois o `sudo` precisa pedir a senha.

## Arquivos

- `PKGBUILD`: extrai o `.deb` e instala os arquivos, reproduzindo o que o `postinst`
  do Debian faria (busca do GNOME, tipos MIME, link `ccd`), sem o repositório apt
  e o perfil do AppArmor.
- `claude-desktop.install`: mensagem pós-instalação.
- `atualizar.sh`: download verificado, build e instalação.

## Cowork (opcional)

```bash
sudo pacman -S qemu-system-x86 edk2-ovmf virtiofsd
```

```bash
sudo usermod -aG kvm $USER
```

Depois saia e entre de novo na sessão.

## Remover

```bash
sudo pacman -R claude-desktop
```
