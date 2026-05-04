#!/usr/bin/env bash
set -euo pipefail

cd /home/frappe/frappe-bench

wait-for-it "$DB_HOST:$DB_PORT" -t 300
wait-for-it redis-cache:6379 -t 120
wait-for-it redis-queue:6379 -t 120
wait-for-it redis-socketio:6379 -t 120

if [ ! -f "sites/$SITE_NAME/site_config.json" ]; then
  echo "[INFO] creation du site $SITE_NAME"

  bench new-site "$SITE_NAME" \
    --no-mariadb-socket \
    --mariadb-user-host-login-scope='%' \
    --db-root-username root \
    --db-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --install-app "$INSTALL_APPS" \
    --set-default
else
  echo "[INFO] site $SITE_NAME existe deja, creation ignoree"
fi

SITE_URL="http://$SITE_HOST"
if [ "${HTTP_PORT}" != "80" ]; then
  SITE_URL="${SITE_URL}:$HTTP_PORT"
fi

bench --site "$SITE_NAME" set-config host_name "$SITE_URL"
bench --site "$SITE_NAME" set-config -p max_file_size 104857600
bench --site "$SITE_NAME" set-config -p server_script_enabled 1

bench --site "$SITE_NAME" migrate
bench --site "$SITE_NAME" enable-scheduler

bench --site "$SITE_NAME" clear-cache
bench --site "$SITE_NAME" clear-website-cache || true

echo "[INFO] create-site termine"
