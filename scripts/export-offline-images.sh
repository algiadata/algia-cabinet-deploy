#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

set -a
. ./.env.example
set +a

mkdir -p offline-images

APP_REF="${APP_IMAGE}:${APP_VERSION}"

docker pull "$APP_REF"
docker pull mariadb:10.6
docker pull redis:7-alpine

docker save "$APP_REF" -o "offline-images/algia-cabinet-app-${APP_VERSION}.tar"
docker save mariadb:10.6 -o "offline-images/mariadb-10.6.tar"
docker save redis:7-alpine -o "offline-images/redis-7-alpine.tar"

sha256sum offline-images/*.tar > offline-images/SHA256_IMAGES.txt

ls -lh offline-images
