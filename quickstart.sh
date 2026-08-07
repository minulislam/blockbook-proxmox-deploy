#!/bin/bash
# =============================================================================
# quickstart.sh — One-command deployment (interactive)
# =============================================================================
# This script runs the entire deployment pipeline with confirmation prompts.
# Run as root on a fresh Debian 12 VM.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "  Blockbook Multi-Coin Quick Start"
echo "============================================"
echo ""
echo "This will deploy Blockbook for:"
echo "  • Bitcoin"
echo "  • Litecoin"
echo "  • Bitcoin Cash"
echo "  • Dash"
echo "  • Zcash"
echo ""
echo "Estimated requirements:"
echo "  • 64 GB RAM"
echo "  • 1.5 TB NVMe SSD"
echo "  • 16 CPU cores"
echo "  • Debian 12 (amd64)"
echo ""

read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Step 1: System prep
echo ""
echo ">>> STEP 1/5: System Preparation"
read -p "Run system prep (updates, Docker, Go, swap)? (yes/no): " RUN_PREP
if [ "$RUN_PREP" == "yes" ]; then
    bash "$SCRIPT_DIR/scripts/01-system-prep.sh"
fi

# Step 2: Build packages
echo ""
echo ">>> STEP 2/5: Build Blockbook Packages"
read -p "Build all .deb packages? This takes 1-3 hours. (yes/no): " RUN_BUILD
if [ "$RUN_BUILD" == "yes" ]; then
    bash "$SCRIPT_DIR/scripts/02-build-blockbook.sh"
fi

# Step 3: Install coins
echo ""
echo ">>> STEP 3/5: Install Coins"
read -p "Install backend + blockbook packages? (yes/no): " RUN_INSTALL
if [ "$RUN_INSTALL" == "yes" ]; then
    bash "$SCRIPT_DIR/scripts/03-install-coins.sh"
fi

# Step 4: Firewall
echo ""
echo ">>> STEP 4/5: Configure Firewall"
read -p "Configure UFW firewall? (yes/no): " RUN_FW
if [ "$RUN_FW" == "yes" ]; then
    bash "$SCRIPT_DIR/scripts/04-firewall.sh"
fi

# Step 5: Nginx + SSL (optional)
echo ""
echo ">>> STEP 5/5: Nginx + SSL (optional)"
read -p "Set up Nginx reverse proxy with SSL? (yes/no/skip): " RUN_NGINX
if [ "$RUN_NGINX" == "yes" ]; then
    read -p "Enter your domain name: " DOMAIN
    bash "$SCRIPT_DIR/scripts/05-nginx-ssl.sh" "$DOMAIN"
elif [ "$RUN_NGINX" == "no" ]; then
    echo "Skipping Nginx. Blockbook APIs are available directly on ports 9130-9134."
fi

echo ""
echo "============================================"
echo "  Quick Start Complete!"
echo "============================================"
echo ""
echo "Check status with:"
echo "  bash $SCRIPT_DIR/scripts/status.sh"
echo ""
echo "Watch Bitcoin sync with:"
echo "  bash $SCRIPT_DIR/scripts/watch-sync.sh bitcoin"
