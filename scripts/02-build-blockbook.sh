#!/bin/bash
set -euo pipefail

# =============================================================================
# 02-build-blockbook.sh — Build Blockbook & Backend Debian Packages
# =============================================================================
# This builds .deb packages for Bitcoin, Litecoin, BCH, Dash, Zcash
# Uses Docker for isolated build environment (official Trezor method)
# Run as root (or with sudo) from /opt/coins/build/blockbook

LOG="/var/log/blockbook-build.log"
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "  Building Blockbook Packages"
echo "  Started: $(date)"
echo "=========================================="

# Ensure we're in the right directory
if [ ! -f "Makefile" ]; then
    echo "ERROR: Must run from blockbook source directory (/opt/coins/build/blockbook)"
    echo "Run: cd /opt/coins/build/blockbook && bash /path/to/02-build-blockbook.sh"
    exit 1
fi

# Coins to build
coins=("bitcoin" "litecoin" "bcash" "dash" "zcash")

echo ""
echo "Building for coins: ${coins[*]}"
echo "This will take a LONG time (1-3 hours depending on hardware)."
echo ""

# Build Docker images first (one-time)
echo "[1/3] Building Docker build images..."
make build-images

# Build all packages
echo "[2/3] Building backend + blockbook packages for all coins..."
for coin in "${coins[@]}"; do
    echo ""
    echo "=== Building: $coin ==="
    echo "Started: $(date)"

    # The 'all-<coin>' target cleans, rebuilds Docker image, and builds both packages
    # For subsequent builds use 'deb-<coin>' instead
    if [ "$coin" == "bcash" ]; then
        # Bitcoin Cash alias in blockbook is 'bcash'
        make "all-bcash" || make "deb-bcash"
    else
        make "all-$coin" || make "deb-$coin"
    fi

    echo "=== $coin complete: $(date) ==="
done

# List built packages
echo ""
echo "[3/3] Built packages:"
ls -lh build/*.deb 2>/dev/null || echo "No packages found in build/"

echo ""
echo "=========================================="
echo "  Build complete!"
echo "  Packages located in: $(pwd)/build/"
echo "  Next step: bash scripts/03-install-coins.sh"
echo "=========================================="
