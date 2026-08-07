#!/bin/bash
set -euo pipefail

# =============================================================================
# 03-install-coins.sh — Install Backend & Blockbook for All Coins
# =============================================================================
# Installs the .deb packages and configures systemd services
# Run as root from /opt/coins/build/blockbook

LOG="/var/log/blockbook-install.log"
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "  Installing Blockbook Coins"
echo "  Started: $(date)"
echo "=========================================="

BUILD_DIR="/opt/coins/build/blockbook/build"

if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: Build directory not found: $BUILD_DIR"
    echo "Run 02-build-blockbook.sh first."
    exit 1
fi

# ---------------------------------------------------------------------------
# Install all .deb packages
# ---------------------------------------------------------------------------
echo "[1/4] Installing Debian packages..."
dpkg -i "$BUILD_DIR"/*.deb || apt-get install -f -y

# Fix any dependency issues
apt-get install -f -y

echo "Packages installed."

# ---------------------------------------------------------------------------
# Enable and start all backend services
# ---------------------------------------------------------------------------
echo "[2/4] Enabling backend node services..."
systemctl daemon-reload

backends=(
    "bitcoin"
    "litecoin"
    "bcash"
    "dash"
    "zcash"
)

for coin in "${backends[@]}"; do
    service="backend-$coin"
    if systemctl list-unit-files "$service.service" &>/dev/null; then
        echo "  Enabling $service..."
        systemctl enable "$service"
        systemctl start "$service"
    else
        echo "  WARNING: $service.service not found — may be named differently"
    fi
done

echo ""
echo "Backend nodes started. They will begin downloading blockchain data."
echo "Wait for backends to finish initial sync before starting blockbook indexers."
echo ""

# ---------------------------------------------------------------------------
# Optional: wait for backend RPC to be ready before starting blockbook
# ---------------------------------------------------------------------------
echo "[3/4] Checking backend RPC availability..."

check_rpc() {
    local port=$1
    local coin=$2
    local max_wait=300  # 5 minutes
    local waited=0
    while ! curl -s --max-time 5 "http://localhost:$port" > /dev/null 2>&1; do
        if [ "$waited" -ge "$max_wait" ]; then
            echo "  WARNING: $coin RPC on port $port not ready after ${max_wait}s"
            return 1
        fi
        sleep 5
        waited=$((waited + 5))
    done
    echo "  $coin RPC ready on port $port"
}

# Check each backend RPC (ports from configs/coins/*.json)
check_rpc 8030 "Bitcoin" || true
check_rpc 8031 "Litecoin" || true
check_rpc 8032 "Bitcoin Cash" || true
check_rpc 8033 "Dash" || true
check_rpc 8034 "Zcash" || true

# ---------------------------------------------------------------------------
# Start Blockbook indexers
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Enabling and starting Blockbook indexers..."

blockbooks=(
    "blockbook-bitcoin"
    "blockbook-litecoin"
    "blockbook-bcash"
    "blockbook-dash"
    "blockbook-zcash"
)

for service in "${blockbooks[@]}"; do
    if systemctl list-unit-files "$service.service" &>/dev/null; then
        echo "  Enabling $service..."
        systemctl enable "$service"
        systemctl start "$service"
    else
        echo "  WARNING: $service.service not found"
    fi
done

# ---------------------------------------------------------------------------
# Status Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Services started:"
systemctl list-units --type=service --state=running | grep -E "(backend|blockbook)" || true
echo ""
echo "Check sync status with:"
echo "  curl -s http://localhost:9130/api/v2 | jq .blockbook.inSync   # Bitcoin"
echo "  curl -s http://localhost:9131/api/v2 | jq .blockbook.inSync   # Litecoin"
echo "  curl -s http://localhost:9132/api/v2 | jq .blockbook.inSync   # BCH"
echo "  curl -s http://localhost:9133/api/v2 | jq .blockbook.inSync   # Dash"
echo "  curl -s http://localhost:9134/api/v2 | jq .blockbook.inSync   # Zcash"
echo ""
echo "Next step: Configure firewall with bash scripts/04-firewall.sh"
