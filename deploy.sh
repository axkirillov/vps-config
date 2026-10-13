#!/bin/bash
set -euo pipefail

REPO_DIR="/root/vps-config"
cd "$REPO_DIR"

echo "=== Pulling latest changes ==="
git pull origin main

echo ""
echo "=== Deploying system configs ==="

# Swap — created before the fstab sync below, because /etc/fstab now carries the
# /swapfile entry and `mount -a` would fail on a host where it does not exist yet.
if ! swapon --show | grep -q '/swapfile'; then
    if [ ! -f /swapfile ]; then
        echo "→ creating 4G swapfile..."
        fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
        chmod 600 /swapfile
        mkswap /swapfile
    fi
    swapon /swapfile
    echo "  Done."
else
    echo "→ swap: active"
fi

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
    # Tolerate a swap entry that is already active or a stale CIFS mount.
    mount -a || echo "  → mount -a reported an error (see above)"
    echo "  Done."
else
    echo "→ fstab: unchanged"
fi

# Swap tuning
if ! diff -q system-configs/sysctl-swap.conf /etc/sysctl.d/99-swap.conf &>/dev/null; then
    echo "→ sysctl-swap.conf changed. Applying..."
    cp system-configs/sysctl-swap.conf /etc/sysctl.d/99-swap.conf
    sysctl -p /etc/sysctl.d/99-swap.conf
    echo "  Done."
else
    echo "→ sysctl-swap.conf: unchanged"
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
echo "=== Swapfile size ==="
# Deliberately last: resizing means swapping off the old file, and everything
# above (notably the Gateway restart) frees the pages it had paged out. Guarded
# on free RAM, because swapoff pulls every swapped page back into memory first.
SWAP_TARGET_MB=4096
if [ -f /swapfile ]; then
    current_mb=$(( $(stat -c %s /swapfile) / 1048576 ))
    if [ "$current_mb" -lt "$SWAP_TARGET_MB" ]; then
        swap_used_mb=$(free -m | awk '/^Swap:/ {print $3}')
        avail_mb=$(free -m | awk '/^Mem:/  {print $7}')
        if [ "$avail_mb" -gt $(( swap_used_mb + 512 )) ]; then
            echo "→ growing swapfile ${current_mb}M -> ${SWAP_TARGET_MB}M (swap used ${swap_used_mb}M, RAM available ${avail_mb}M)"
            swapoff /swapfile
            fallocate -l ${SWAP_TARGET_MB}M /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_TARGET_MB
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo "  Done."
        else
            echo "→ resize deferred: ${swap_used_mb}M swapped, only ${avail_mb}M RAM available — rerun when the host is quieter"
        fi
    else
        echo "→ swapfile: ${current_mb}M"
    fi
fi

echo ""
echo "=== Deploy complete ==="
