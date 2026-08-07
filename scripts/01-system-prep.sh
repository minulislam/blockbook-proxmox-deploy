#!/bin/bash
set -euo pipefail

# =============================================================================
# 01-system-prep.sh — System Preparation for Blockbook Multi-Coin Node
# =============================================================================
# Run as root on Debian 12 VM
# This script: updates system, installs deps, Docker, Go, configures swap

COIN="multicoin"
LOG="/var/log/blockbook-prep.log"
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "  Blockbook Multi-Coin System Prep"
echo "  Started: $(date)"
echo "=========================================="

# ---------------------------------------------------------------------------
# 1. System Update
# ---------------------------------------------------------------------------
echo "[1/7] Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get install -y \
    build-essential git wget curl htop iotop tmux jq \
    libzmq3-dev libgflags-dev libsnappy-dev zlib1g-dev \
    libzstd-dev libbz2-dev liblz4-dev pkg-config \
    ca-certificates gnupg lsb-release software-properties-common \
    ufw nginx certbot python3-certbot-nginx \
    net-tools sqlite3 libtool autoconf automake

# ---------------------------------------------------------------------------
# 2. Configure Swap (32GB for systems with <64GB RAM)
# ---------------------------------------------------------------------------
echo "[2/7] Configuring swap..."
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

if [ "$TOTAL_RAM_GB" -lt 64 ]; then
    echo "RAM is ${TOTAL_RAM_GB}GB (< 64GB). Adding 32GB swap file..."
    if [ ! -f /swapfile ]; then
        fallocate -l 32G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=32768
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    sysctl vm.swappiness=10
    echo 'vm.swappiness = 10' >> /etc/sysctl.conf
    sysctl vm.vfs_cache_pressure=50
    echo 'vm.vfs_cache_pressure = 50' >> /etc/sysctl.conf
else
    echo "RAM is ${TOTAL_RAM_GB}GB (>= 64GB). No extra swap needed."
    if [ ! -f /swapfile ]; then
        fallocate -l 8G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
fi

# ---------------------------------------------------------------------------
# 3. Install Docker
# ---------------------------------------------------------------------------
echo "[3/7] Installing Docker..."
if ! command -v docker &> /dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker "${SUDO_USER:-root}"
    echo "Docker installed. You may need to log out and back in for group changes."
else
    echo "Docker already installed."
fi

# ---------------------------------------------------------------------------
# 4. Install Go (Blockbook uses Go 1.22+)
# ---------------------------------------------------------------------------
echo "[4/7] Installing Go..."
GO_VERSION="1.22.8"
if ! command -v go &> /dev/null || [ "$(go version | awk '{print $3}')" != "go${GO_VERSION}" ]; then
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
fi

# Add Go to PATH
if ! grep -q '/usr/local/go/bin' /etc/profile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    echo 'export GOPATH=$HOME/go' >> /etc/profile
    echo 'export PATH=$PATH:$GOPATH/bin' >> /etc/profile
fi
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

echo "Go version: $(go version)"

# ---------------------------------------------------------------------------
# 5. Create Data Directories
# ---------------------------------------------------------------------------
echo "[5/7] Creating data directories..."
mkdir -p /opt/coins/data
mkdir -p /opt/coins/nodes
mkdir -p /opt/coins/blockbook
mkdir -p /opt/coins/build
chown -R root:root /opt/coins

# ---------------------------------------------------------------------------
# 6. Increase System Limits
# ---------------------------------------------------------------------------
echo "[6/7] Setting system limits..."
cat >> /etc/sysctl.conf << 'EOF'
# Blockbook optimizations
fs.file-max = 200000
vm.max_map_count = 262144
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
EOF
sysctl -p

# ---------------------------------------------------------------------------
# 7. Create Build Environment
# ---------------------------------------------------------------------------
echo "[7/7] Setting up build environment..."
cd /opt/coins/build
if [ ! -d "blockbook" ]; then
    git clone https://github.com/trezor/blockbook.git
    cd blockbook
else
    cd blockbook
    git pull origin master
fi

echo ""
echo "=========================================="
echo "  System prep complete!"
echo "  Next step: bash scripts/02-build-blockbook.sh"
echo "=========================================="
