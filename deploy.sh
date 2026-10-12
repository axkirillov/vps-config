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

# Swap
if ! swapon --show | grep -q '/swapfile'; then
    if [ ! -f /swapfile ]; then
        echo "→ creating 2G swapfile..."
        fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
        chmod 600 /swapfile
        mkswap /swapfile
    fi
    swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
    grep -q '^vm.swappiness' /etc/sysctl.conf || echo 'vm.swappiness=10' >>/etc/sysctl.conf
    sysctl -p >/dev/null
    echo "  Done."
else
    echo "→ swap: active"
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
echo "=== Deploying Ghost ==="
docker compose -f ghost-app/docker-compose.yml up -d

echo ""
echo "=== Deploying Supabase ==="
docker compose -f supabase-app/docker-compose.yml up -d

echo ""
echo "=== Deploying OpenClaw ==="
if [ -f openclaw-app/.env ]; then
    # Only the gateway: openclaw-cli is a one-shot admin container.
    docker compose -f openclaw-app/docker-compose.yml up -d openclaw-gateway
else
    echo "→ skipped: openclaw-app/.env missing (copy .env.example and set OPENCLAW_GATEWAY_TOKEN)"
fi

echo ""
echo "=== Deploy complete ==="
