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

for file in \
  docker-compose.yml \
  .env.example \
  README.md \
  INSTALLATION_CLIENT.txt
do
  if [ -f "$file" ]; then
    cp -f "$file" "$PACK_DIR/"
  else
    echo "ERREUR: fichier manquant: $file"
    exit 1
  fi
done

for dir in \
  bootstrap \
  manifests \
  installer \
  docs
do
  if [ -d "$dir" ]; then
    cp -a "$dir" "$PACK_DIR/"
  else
    echo "ERREUR: dossier manquant: $dir"
    exit 1
  fi
done

if [ -f "$EXE_SOURCE" ]; then
  cp -f "$EXE_SOURCE" "$PACK_DIR/algia-cabinet-installer-win64.exe"
else
  cat > "$PACK_DIR/A_COMPILER_SUR_WINDOWS.txt" <<'TXT'
Le fichier algia-cabinet-installer-win64.exe n'existe pas encore.

Pour le creer :
1. Compiler le launcher Windows.
2. Copier l'executable dans releases/algia-cabinet-installer-win64.exe.
3. Relancer scripts/build-client-folder.sh.
TXT
fi

if [ -d offline-images ]; then
  cp -a offline-images/. "$PACK_DIR/offline-images/" 2>/dev/null || true
fi

if [ -f "$PACK_DIR/.env" ]; then
  echo "ERREUR: .env ne doit pas etre inclus dans le pack client"
  exit 1
fi

(
  cd "$PACK_DIR"
  find . -type f ! -name SHA256.txt -print0 | sort -z | xargs -0 sha256sum > SHA256.txt
)

echo "$PACK_DIR"
ls -lah "$PACK_DIR"
