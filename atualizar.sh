#!/usr/bin/env bash
# Atualiza o Claude Desktop no Arch a partir do .deb oficial da Anthropic.
#
# Fluxo: baixa a chave e o índice assinado do repositório apt oficial,
# verifica a assinatura (fingerprint fixo), confere os hashes em cadeia
# (InRelease -> Packages -> .deb), atualiza o PKGBUILD, roda makepkg e
# instala com pacman.
#
# Uso: ./atualizar.sh [--force]   (--force reconstrói mesmo se já estiver atualizado)
set -euo pipefail

REPO="https://downloads.claude.ai/claude-desktop/apt/stable"
KEY_URL="https://downloads.claude.ai/claude-desktop/key.asc"
FINGERPRINT="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

die() { echo "ERRO: $*" >&2; exit 1; }
info() { echo "==> $*"; }

for cmd in curl gpg sha256sum makepkg pacman awk sed; do
  command -v "$cmd" >/dev/null || die "comando '$cmd' não encontrado"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GNUPGHOME="$TMP/gnupg"
mkdir -m 700 "$GNUPGHOME"

# 1. Chave de assinatura, conferindo o fingerprint
info "Baixando chave de assinatura..."
curl -fsSL "$KEY_URL" -o "$TMP/key.asc"
gpg --batch --quiet --import "$TMP/key.asc" 2>/dev/null
gpg --batch --with-colons --fingerprint "$FINGERPRINT" >/dev/null 2>&1 \
  || die "a chave baixada não tem o fingerprint esperado ($FINGERPRINT)"

# 2. InRelease assinado; só o conteúdo verificado é usado daqui em diante
info "Verificando assinatura do repositório..."
curl -fsSL "$REPO/dists/stable/InRelease" -o "$TMP/InRelease"
gpg --batch --status-fd 3 --output "$TMP/Release" --decrypt "$TMP/InRelease" \
  3>"$TMP/status" 2>/dev/null || die "falha ao verificar InRelease"
grep -q "^\[GNUPG:\] VALIDSIG .* $FINGERPRINT\$" "$TMP/status" \
  || grep -q "^\[GNUPG:\] VALIDSIG $FINGERPRINT " "$TMP/status" \
  || die "assinatura do InRelease inválida ou de outra chave"

# 3. Índice Packages, conferido contra o SHA256 do Release verificado
curl -fsSL "$REPO/dists/stable/main/binary-amd64/Packages" -o "$TMP/Packages"
expected=$(awk '/^SHA256:/{s=1;next} /^[^ ]/{s=0} s && $3=="main/binary-amd64/Packages"{print $1}' "$TMP/Release")
[[ -n "$expected" ]] || die "hash do Packages não encontrado no Release"
[[ "$(sha256sum "$TMP/Packages" | cut -d' ' -f1)" == "$expected" ]] \
  || die "hash do Packages não confere"

# 4. Versão mais recente e seu SHA256
read -r version filename sha < <(awk '
  /^Package: /{p=$2} /^Version: /{v=$2} /^Filename: /{f=$2} /^SHA256: /{h=$2}
  /^$/{ if (p=="claude-desktop") print v, f, h; p=v=f=h="" }
  END{ if (p=="claude-desktop") print v, f, h }' "$TMP/Packages" | sort -V -k1,1 | tail -n1)
[[ -n "${version:-}" && -n "${sha:-}" ]] || die "não foi possível achar o pacote no índice"
[[ "$version" =~ ^[0-9][0-9.]*$ ]] || die "versão inesperada: $version"

installed=$(pacman -Q claude-desktop 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//' || true)
info "Instalada: ${installed:-nenhuma} | Disponível: $version"
if [[ "$installed" == "$version" && $FORCE -eq 0 ]]; then
  info "Já está na versão mais recente. Use --force para reinstalar."
  exit 0
fi

# 5. Baixa o .deb e confere o hash
deb="claude-desktop_${version}_amd64.deb"
if [[ ! -f "$DIR/$deb" ]] || [[ "$(sha256sum "$DIR/$deb" | cut -d' ' -f1)" != "$sha" ]]; then
  info "Baixando $deb..."
  curl -fL "$REPO/$filename" -o "$TMP/$deb"
  [[ "$(sha256sum "$TMP/$deb" | cut -d' ' -f1)" == "$sha" ]] || die "hash do .deb não confere"
  mv "$TMP/$deb" "$DIR/$deb"
fi
info "SHA256 do .deb verificado."

# 6. Atualiza o PKGBUILD e constrói
cd "$DIR"
sed -i -e "s/^pkgver=.*/pkgver=$version/" \
       -e "s/^pkgrel=.*/pkgrel=1/" \
       -e "s/^sha256sums=.*/sha256sums=('$sha')/" PKGBUILD
info "Construindo o pacote..."
makepkg -f --cleanbuild
rm -rf "$DIR/src" "$DIR/pkg"

pkgfile="$DIR/claude-desktop-${version}-1-x86_64.pkg.tar.zst"
[[ -f "$pkgfile" ]] || die "pacote não foi gerado"

# 7. Instala (sudo precisa de um terminal interativo para pedir a senha)
if [[ ! -t 0 ]] && ! sudo -n true 2>/dev/null; then
  info "Pacote gerado, mas não há terminal para pedir a senha do sudo."
  info "Instale num terminal com: sudo pacman -U $pkgfile"
  exit 0
fi
info "Instalando (vai pedir a senha do sudo)..."
sudo pacman -U "$pkgfile"

# 8. Remove .deb e pacotes de versões antigas
find "$DIR" -maxdepth 1 \( -name 'claude-desktop_*_amd64.deb' ! -name "$deb" \
  -o -name 'claude-desktop-*-x86_64.pkg.tar.zst' ! -name "${pkgfile##*/}" \) -print -delete

info "Pronto: Claude Desktop $version instalado."
