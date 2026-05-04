#!/usr/bin/env bash
set -euo pipefail

cd /home/frappe/frappe-bench

ls -1 apps > sites/apps.txt
bench set-config -g db_host "$DB_HOST"
bench set-config -gp db_port "$DB_PORT"
bench set-config -g redis_cache "$REDIS_CACHE_URL"
bench set-config -g redis_queue "$REDIS_QUEUE_URL"
bench set-config -g redis_socketio "$REDIS_SOCKETIO_URL"
bench set-config -gp socketio_port "$SOCKETIO_PORT"
bench set-config -gp server_script_enabled 1

echo "[INFO] configurator ALGIA Cabinet termine"
