#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="${1:-$(date +%Y%m%d-%H%M%S)}"
PACK_NAME="ALGIA-Cabinet-Windows-$STAMP"
BUILD_ROOT="$ROOT/.build-release"
PACK_DIR="$BUILD_ROOT/$PACK_NAME"
ZIP_FILE="$ROOT/releases/$PACK_NAME.zip"

cd "$ROOT"

echo "=== VERIF FICHIERS OBLIGATOIRES ==="

for file in \
  README.md \
  docker-compose.yml \
  .env.example \
  INSTALLER-ALGIA-CABINET.bat \
  DEMARRER-ALGIA-CABINET.bat \
  ARRETER-ALGIA-CABINET.bat \
  SAUVEGARDE-ALGIA-CABINET.bat \
  METTRE-A-JOUR-ALGIA-CABINET.bat \
  RESTAURER-ALGIA-CABINET.bat \
  installer/windows/scripts/update.ps1 \
  installer/windows/scripts/restore.ps1 \
  manifests/release.json \
  bootstrap/configurator.sh \
  bootstrap/create-site.sh
do
  if [ ! -f "$file" ]; then
    echo "ERREUR: fichier manquant: $file"
    exit 1
  fi
done

for dir in \
  installer/windows/scripts \
  docs
do
  if [ ! -d "$dir" ]; then
    echo "ERREUR: dossier manquant: $dir"
    exit 1
  fi
done

echo "=== VALIDATION DOCKER COMPOSE ==="
docker compose --env-file .env.example config >/dev/null

echo "=== VALIDATION SCRIPTS BASH ==="
bash -n bootstrap/configurator.sh
bash -n bootstrap/create-site.sh

echo "=== PREPARE BUILD ==="
rm -rf "$BUILD_ROOT"
mkdir -p "$PACK_DIR"
mkdir -p "$ROOT/releases"

echo "=== COPY FILES ==="
cp -f README.md "$PACK_DIR/"
cp -f docker-compose.yml "$PACK_DIR/"
cp -f .env.example "$PACK_DIR/"
cp -f INSTALLER-ALGIA-CABINET.bat "$PACK_DIR/"
cp -f DEMARRER-ALGIA-CABINET.bat "$PACK_DIR/"
cp -f ARRETER-ALGIA-CABINET.bat "$PACK_DIR/"
cp -f SAUVEGARDE-ALGIA-CABINET.bat "$PACK_DIR/"
cp -f METTRE-A-JOUR-ALGIA-CABINET.bat "$PACK_DIR/"
cp -f RESTAURER-ALGIA-CABINET.bat "$PACK_DIR/"

mkdir -p "$PACK_DIR/installer"
mkdir -p "$PACK_DIR/docs"
mkdir -p "$PACK_DIR/backups"
mkdir -p "$PACK_DIR/releases"
mkdir -p "$PACK_DIR/logs"
mkdir -p "$PACK_DIR/state"
mkdir -p "$PACK_DIR/manifests"
mkdir -p "$PACK_DIR/bootstrap"

cp -r installer/windows "$PACK_DIR/installer/"
cp -r docs/. "$PACK_DIR/docs/"
cp -f manifests/release.json "$PACK_DIR/manifests/"
cp -f bootstrap/configurator.sh "$PACK_DIR/bootstrap/"
cp -f bootstrap/create-site.sh "$PACK_DIR/bootstrap/"

touch "$PACK_DIR/backups/.gitkeep"
touch "$PACK_DIR/releases/.gitkeep"
touch "$PACK_DIR/logs/.gitkeep"
touch "$PACK_DIR/state/.gitkeep"

cat > "$PACK_DIR/LISEZ-MOI.txt" <<'TXT'
ALGIA Cabinet - Installation Windows

1. Installer Docker Desktop.
2. Lancer Docker Desktop.
3. Double-cliquer sur INSTALLER-ALGIA-CABINET.bat.
4. Ouvrir http://localhost:8080.
5. Utilisateur : Administrator.
6. Mot de passe : voir le fichier .env généré après installation.

Boutons disponibles :

- INSTALLER-ALGIA-CABINET.bat
- DEMARRER-ALGIA-CABINET.bat
- ARRETER-ALGIA-CABINET.bat
- SAUVEGARDE-ALGIA-CABINET.bat
- METTRE-A-JOUR-ALGIA-CABINET.bat
- RESTAURER-ALGIA-CABINET.bat

Sauvegarde :
Le bouton de sauvegarde demande le dossier ou stocker la sauvegarde.

Mise a jour :
Le bouton de mise a jour cree une sauvegarde de securite avant de telecharger la nouvelle image Docker.

Restauration :
Le bouton de restauration demande le dossier de sauvegarde a restaurer.

Ne supprimez pas le fichier .env apres installation.
Les donnees restent sur le PC local via Docker.
TXT

echo "=== VERIF PAS DE SECRET ==="

if [ -f "$PACK_DIR/.env" ]; then
  echo "ERREUR: .env present dans le pack"
  exit 1
fi

if grep -R "ADMIN_PASSWORD=Admin-" "$PACK_DIR" >/dev/null 2>&1; then
  echo "ERREUR: mot de passe admin detecte dans le pack"
  exit 1
fi

echo "=== ZIP ==="
rm -f "$ZIP_FILE"
cd "$BUILD_ROOT"
zip -r "$ZIP_FILE" "$PACK_NAME" >/dev/null

echo "=== CHECK ZIP ==="
unzip -l "$ZIP_FILE" | grep -E '(^|/)\.env$' && echo "ERREUR: .env present dans le ZIP" && exit 1 || true

echo "=== RELEASE OK ==="
ls -lh "$ZIP_FILE"
echo "$ZIP_FILE"
