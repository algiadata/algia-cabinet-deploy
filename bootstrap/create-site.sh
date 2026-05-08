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

echo "[INFO] verification parametres planning cabinet"

mkdir -p "sites/$SITE_NAME/logs" "/home/frappe/logs" "/home/frappe/frappe-bench/logs"

cat > /tmp/ensure_parametres_cabinet.py <<'PY'
import os
import sys
import frappe

TARGET = {
    "heure_ouverture": "09:00:00",
    "heure_fermeture": "18:30:00",
    "duree_creneau_minutes": 15,
    "jours_ouvrables": "0,1,2,3,4,5",
    "pause_debut": "12:00:00",
    "pause_fin": "13:00:00",
}

BAD_DAYS = {"6,0,1,2,3,", "6,0,1,2,3"}


def norm_time(value):
    return str(value or "").strip()[:5]


def norm_days(value):
    return "".join(str(value or "").split())


def as_int(value, default=0):
    try:
        return int(value or default)
    except Exception:
        return default


def is_blank(value):
    return value is None or str(value).strip() == ""


site = os.environ.get("SITE_NAME", "cabinet.local")

try:
    frappe.init(site=site)
    frappe.connect()
    frappe.set_user("Administrator")

    doc = frappe.get_single("Parametres Cabinet")

    current = {
        "heure_ouverture": doc.heure_ouverture,
        "heure_fermeture": doc.heure_fermeture,
        "duree_creneau_minutes": doc.duree_creneau_minutes,
        "jours_ouvrables": doc.jours_ouvrables,
        "pause_debut": doc.pause_debut,
        "pause_fin": doc.pause_fin,
    }

    changed = []

    known_bad_default = (
        norm_time(current["heure_ouverture"]) == "08:00"
        and norm_time(current["heure_fermeture"]) == "17:00"
        and as_int(current["duree_creneau_minutes"]) == 20
        and norm_days(current["jours_ouvrables"]) in BAD_DAYS
    )

    missing_core = (
        is_blank(current["heure_ouverture"])
        or is_blank(current["heure_fermeture"])
        or as_int(current["duree_creneau_minutes"]) <= 0
        or is_blank(current["jours_ouvrables"])
    )

    if known_bad_default or missing_core:
        for field, value in TARGET.items():
            setattr(doc, field, value)
            changed.append(field)
    else:
        if norm_days(current["jours_ouvrables"]) in BAD_DAYS:
            doc.jours_ouvrables = TARGET["jours_ouvrables"]
            changed.append("jours_ouvrables")

    if changed:
        doc.save(ignore_permissions=True)
        frappe.db.commit()
        frappe.clear_cache()
        print("[INFO] Parametres Cabinet corriges: " + ", ".join(sorted(set(changed))))
    else:
        print("[INFO] Parametres Cabinet conserves")

except Exception as exc:
    print("[WARN] Parametres Cabinet non ajustes: " + str(exc), file=sys.stderr)
finally:
    try:
        frappe.destroy()
    except Exception:
        pass
PY

(
  cd /home/frappe/frappe-bench/sites
  SITE_NAME="$SITE_NAME" /home/frappe/frappe-bench/env/bin/python /tmp/ensure_parametres_cabinet.py
)

bench --site "$SITE_NAME" enable-scheduler

bench --site "$SITE_NAME" clear-cache
bench --site "$SITE_NAME" clear-website-cache || true

echo "[INFO] create-site termine"