#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
COMMIT_MESSAGE="${2:-}"

APP_REPO="${APP_REPO:-/home/frappe/frappe-bench/apps/algia_cabinet}"
IMAGE_BUILD_DIR="${IMAGE_BUILD_DIR:-/home/frappe/algia-cabinet-image-build}"
DEPLOY_REPO="${DEPLOY_REPO:-/home/frappe/algia-cabinet-deploy}"
APP_IMAGE="${APP_IMAGE:-algiadata/algia-cabinet}"

if [ -z "$VERSION" ]; then
  echo "ERREUR: version manquante. Exemple: ./scripts/release-new-version.sh v0.1.1 \"Patients page update\""
  exit 1
fi

if [[ "$VERSION" != v* ]]; then
  echo "ERREUR: la version doit commencer par v. Exemple: v0.1.1"
  exit 1
fi

command -v git >/dev/null
command -v docker >/dev/null
command -v rsync >/dev/null
command -v python3 >/dev/null

cd "$APP_REPO"

APP_BRANCH="$(git branch --show-current)"
APP_STATUS="$(git status --short)"

if [ -n "$APP_STATUS" ]; then
  if [ -z "$COMMIT_MESSAGE" ]; then
    echo "ERREUR: changements non commites dans $APP_REPO"
    git status --short
    echo ""
    echo "Relance avec un message:"
    echo "./scripts/release-new-version.sh $VERSION \"Message du changement\""
    exit 1
  fi

  git add -A
  git commit -m "$COMMIT_MESSAGE"
  git push origin "$APP_BRANCH"
fi

APP_COMMIT="$(git rev-parse HEAD)"

cd "$IMAGE_BUILD_DIR"

rm -rf apps/algia_cabinet
mkdir -p apps

rsync -a --delete \
  --exclude ".git" \
  --exclude "__pycache__" \
  --exclude "*.pyc" \
  --exclude "node_modules" \
  "$APP_REPO/" \
  apps/algia_cabinet/

docker build \
  -t "$APP_IMAGE:$VERSION" \
  -t "$APP_IMAGE:latest" \
  .

docker push "$APP_IMAGE:$VERSION"
docker push "$APP_IMAGE:latest"

cd "$DEPLOY_REPO"

python3 - "$VERSION" "$APP_IMAGE" "$APP_COMMIT" <<'PY'
import json
import sys
from pathlib import Path

version = sys.argv[1]
app_image = sys.argv[2]
app_commit = sys.argv[3]

path = Path("manifests/release.json")
data = json.loads(path.read_text(encoding="utf-8-sig"))

data["version"] = version
data["image"] = f"{app_image}:{version}"
data["app_git_commit"] = app_commit

path.write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8"
)
PY

python3 - "$VERSION" "$APP_IMAGE" <<'PY'
import sys
from pathlib import Path

version = sys.argv[1]
app_image = sys.argv[2]

path = Path(".env.example")
lines = path.read_text(encoding="utf-8-sig").splitlines()
out = []

for line in lines:
    if line.startswith("APP_IMAGE="):
        out.append(f"APP_IMAGE={app_image}")
    elif line.startswith("APP_VERSION="):
        out.append(f"APP_VERSION={version}")
    else:
        out.append(line)

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY

rm -f offline-images/algia-cabinet-app-*.tar
./scripts/export-offline-images.sh
./scripts/build-client-folder.sh

git add manifests/release.json .env.example scripts/release-new-version.sh

if ! git diff --cached --quiet; then
  git commit -m "Release ALGIA Cabinet $VERSION"
  git push origin "$(git branch --show-current)"
fi

echo ""
echo "============================================================"
echo "ALGIA Cabinet release image terminee"
echo "Version: $VERSION"
echo "Image: $APP_IMAGE:$VERSION"
echo "App commit: $APP_COMMIT"
echo "Pack: $DEPLOY_REPO/releases/ALGIA-Cabinet-Client-$VERSION"
echo "============================================================"
