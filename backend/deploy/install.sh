#!/usr/bin/env bash
# Install / upgrade the WearOrder AI backend on a Debian 12 host.
#
# Run as root or with sudo. Idempotent — re-running is safe.
#
# Prereqs you must do BEFORE running this script:
#   1. Install Go 1.22+ (download from https://go.dev/dl, NOT apt — apt
#      ships an old 1.19).
#   2. Have your domain pointing at this server (A record).
#   3. Have ICP filing approved if you're going to make this public.
#
# Usage:
#   sudo bash backend/deploy/install.sh

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BACKEND_SRC="${REPO_ROOT}/backend"
INSTALL_DIR="/opt/wearorder"
DATA_DIR="${INSTALL_DIR}/data"
ETC_DIR="/etc/wearorder"
SERVICE_USER="wearorder"
BIN_NAME="wearorder-api"
GO_BIN="${GO_BIN:-/usr/local/go/bin/go}"

echo "==> Checking prerequisites"
if [[ $EUID -ne 0 ]]; then
    echo "Must run as root (try: sudo bash $0)" >&2
    exit 1
fi

if ! command -v "${GO_BIN}" >/dev/null 2>&1; then
    echo "Go not found at ${GO_BIN}. Install from https://go.dev/dl/ first." >&2
    echo "  cd /tmp && wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz" >&2
    echo "  rm -rf /usr/local/go && tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz" >&2
    exit 1
fi

GO_VERSION=$("${GO_BIN}" version | awk '{print $3}')
echo "    Go: ${GO_VERSION}"

echo "==> Creating service user (if missing)"
if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "${SERVICE_USER}"
fi

echo "==> Creating directories"
mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "${ETC_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_DIR}"

echo "==> Building binary from ${BACKEND_SRC}"
cd "${BACKEND_SRC}"
sudo -u "${SERVICE_USER}" -E env HOME=/tmp "${GO_BIN}" build -trimpath -ldflags='-s -w' -o "${INSTALL_DIR}/${BIN_NAME}.new" ./...
chmod 755 "${INSTALL_DIR}/${BIN_NAME}.new"

echo "==> Installing config skeleton (if missing)"
if [[ ! -f "${ETC_DIR}/wearorder.env" ]]; then
    cp "${BACKEND_SRC}/deploy/wearorder.env.example" "${ETC_DIR}/wearorder.env"
    chmod 600 "${ETC_DIR}/wearorder.env"
    echo "    -> wrote ${ETC_DIR}/wearorder.env (edit before first start)"
else
    echo "    -> ${ETC_DIR}/wearorder.env exists, leaving alone"
fi

echo "==> Installing systemd unit"
cp "${BACKEND_SRC}/deploy/wearorder-api.service" /etc/systemd/system/wearorder-api.service
systemctl daemon-reload

echo "==> Atomically swapping binary"
mv "${INSTALL_DIR}/${BIN_NAME}.new" "${INSTALL_DIR}/${BIN_NAME}"

if systemctl is-active --quiet wearorder-api; then
    echo "==> Restarting wearorder-api"
    systemctl restart wearorder-api
else
    echo "==> Service not yet running. Start manually after editing ${ETC_DIR}/wearorder.env:"
    echo "    sudo systemctl enable --now wearorder-api"
    echo "    sudo journalctl -u wearorder-api -f"
fi

echo
echo "Install complete."
echo "  • Binary:  ${INSTALL_DIR}/${BIN_NAME}"
echo "  • Config:  ${ETC_DIR}/wearorder.env"
echo "  • Data:    ${DATA_DIR}"
echo "  • Logs:    journalctl -u wearorder-api -f"
echo
echo "Next steps:"
echo "  1. Edit ${ETC_DIR}/wearorder.env (set ADMIN_INITIAL_PASSWORD + SESSION_SECRET)"
echo "  2. systemctl enable --now wearorder-api"
echo "  3. Configure Nginx (see backend/deploy/nginx.conf.example)"
echo "  4. certbot --nginx -d api.your-domain.com"
