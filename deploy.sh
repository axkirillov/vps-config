#!/bin/bash
set -euo pipefail

REPO_DIR="/root/vps-config"
cd "$REPO_DIR"

echo "=== Pulling latest changes ==="
git pull origin main

echo ""
echo "=== Deploying system configs ==="

# Docker daemon
if ! diff -q system-configs/docker-daemon.json /etc/docker/daemon.json &>/dev/null; then
    echo "→ docker-daemon.json changed. Updating and restarting docker..."
    cp system-configs/docker-daemon.json /etc/docker/daemon.json
    systemctl restart docker
    echo "  Done."
else
    echo "→ docker-daemon.json: unchanged"
fi

# fstab
if ! diff -q system-configs/fstab /etc/fstab &>/dev/null; then
    echo "→ fstab changed. Updating and remounting..."
    cp system-configs/fstab /etc/fstab
    mount -a
    echo "  Done."
else
    echo "→ fstab: unchanged"
fi

echo ""
echo "=== Deploying Caddy ==="
docker compose -f caddy/docker-compose.yml up -d

echo ""
echo "=== Deploying Immich ==="
docker compose -f immich-app/docker-compose.yml up -d

echo ""
echo "=== Deploying Nextcloud ==="
docker compose -f nextcloud-app/docker-compose.yml up -d

echo ""
echo "=== Deploy complete ==="
