#!/usr/bin/env bash
# Daily SQLite backup for wearorder-api running in Docker.
#
# Install on the server (one-time):
#   sudo cp /srv/wearorder/backend/deploy/backup-cron.sh /etc/cron.daily/wearorder-backup
#   sudo chmod 755 /etc/cron.daily/wearorder-backup
#
# After install, cron runs this once a day. Backups go to
# /var/backups/wearorder-YYYY-MM-DD.db. Files older than 14 days are
# pruned automatically.
#
# Why use sqlite3 .backup instead of cp:
#   - .backup is online-safe — it grabs a consistent snapshot even
#     while wearorder-api is writing. cp can produce torn backups
#     if a write transaction is mid-flight.
#   - SQLite's WAL mode means raw cp would also need to copy
#     -wal and -shm files. .backup folds them into a single file.

set -euo pipefail

CONTAINER_NAME="wearorder-api"
BACKUP_DIR="/var/backups"
RETAIN_DAYS=14

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"  # contains DB with API keys, lock down.

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[wearorder-backup] $CONTAINER_NAME not running, skipping" >&2
    exit 0
fi

DATESTAMP=$(date +%F)
DEST="$BACKUP_DIR/wearorder-${DATESTAMP}.db"

# Run the .backup command inside the container so we use the same
# SQLite version that wrote the DB. Output to stdout, redirect to host.
docker exec "$CONTAINER_NAME" /bin/sh -c '
    apk info -e sqlite >/dev/null 2>&1 || apk add --no-cache sqlite >/dev/null 2>&1
    sqlite3 /data/wearorder.db ".backup /tmp/_backup.db"
    cat /tmp/_backup.db
    rm -f /tmp/_backup.db
' > "${DEST}.tmp"

# Atomic rename — if the redirect fails partway, no partial file is
# left at the canonical name.
mv "${DEST}.tmp" "$DEST"
chmod 600 "$DEST"

# Prune old backups. -mtime +N means "modified more than N days ago".
find "$BACKUP_DIR" -maxdepth 1 -name 'wearorder-*.db' -type f -mtime +${RETAIN_DAYS} -delete

# Optional: log size to syslog so anomalies (sudden growth/shrinkage)
# show up in journal.
SIZE=$(stat -c '%s' "$DEST" 2>/dev/null || stat -f '%z' "$DEST" 2>/dev/null || echo "?")
logger -t wearorder-backup "backed up to $DEST ($SIZE bytes)"
