#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("manifests/release.json").read_text(encoding="utf-8"))
print(data["version"])
PY
)"

PACK_DIR="$ROOT/releases/ALGIA-Cabinet-Client-${VERSION}"
EXE_SOURCE="$ROOT/releases/algia-cabinet-installer-win64.exe"

rm -rf "$PACK_DIR"
mkdir -p "$PACK_DIR/offline-images"

if [ -f "$EXE_SOURCE" ]; then
  cp -f "$EXE_SOURCE" "$PACK_DIR/algia-cabinet-installer-win64.exe"
else
  cat > "$PACK_DIR/A_COMPILER_SUR_WINDOWS.txt" <<'TXT'
Le fichier algia-cabinet-installer-win64.exe n'existe pas encore.

Pour le creer :
1. Installer Inno Setup sur Windows.
2. Ouvrir installer/windows/inno/algia-cabinet-installer.iss.
3. Compiler le script.
4. Copier releases/algia-cabinet-installer-win64.exe dans ce dossier client.
TXT
fi

cp -f INSTALLATION_CLIENT.txt "$PACK_DIR/"

if [ -d offline-images ]; then
  cp -a offline-images/. "$PACK_DIR/offline-images/" 2>/dev/null || true
fi

(
  cd "$PACK_DIR"
  find . -type f ! -name SHA256.txt -print0 | sort -z | xargs -0 sha256sum > SHA256.txt
)

echo "$PACK_DIR"
ls -lah "$PACK_DIR"
