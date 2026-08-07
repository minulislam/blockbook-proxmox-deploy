#!/bin/bash
set -euo pipefail

# =============================================================================
# 04-firewall.sh — Configure UFW Firewall for Blockbook
# =============================================================================
# Opens only necessary ports. Blockbook public ports are proxied via Nginx.
# Backend RPC ports remain localhost-only by default.

echo "=========================================="
echo "  Configuring Firewall (UFW)"
echo "=========================================="

# Reset UFW to safe defaults
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (critical — don't lock yourself out!)
ufw allow 22/tcp comment 'SSH'

# Allow HTTP/HTTPS (Nginx will proxy to Blockbook)
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Optionally: allow direct Blockbook public ports (if not using Nginx)
# Uncomment if you want direct access without reverse proxy:
# ufw allow 9130/tcp comment 'Blockbook Bitcoin'
# ufw allow 9131/tcp comment 'Blockbook Litecoin'
# ufw allow 9132/tcp comment 'Blockbook BCH'
# ufw allow 9133/tcp comment 'Blockbook Dash'
# ufw allow 9134/tcp comment 'Blockbook Zcash'

# Allow specific IPs for management (replace with your actual IP)
# ufw allow from YOUR_IP_ADDRESS to any port 22
# ufw allow from YOUR_IP_ADDRESS to any port 9130:9134

# Enable firewall
echo "Enabling UFW..."
ufw --force enable

echo ""
echo "UFW status:"
ufw status verbose

echo ""
echo "=========================================="
echo "  Firewall configured!"
echo "=========================================="
