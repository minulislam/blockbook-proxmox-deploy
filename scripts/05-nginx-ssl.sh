#!/bin/bash
set -euo pipefail

# =============================================================================
# 05-nginx-ssl.sh — Nginx Reverse Proxy + SSL (Let's Encrypt)
# =============================================================================
# Sets up Nginx to proxy Blockbook APIs with SSL certificates.
# Requires a domain name pointing to this server.

LOG="/var/log/blockbook-nginx.log"
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "  Setting up Nginx + SSL"
echo "=========================================="

# Check if domain is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <your-domain.com>"
    echo "Example: $0 blockbook.example.com"
    echo ""
    echo "Your domain must have A/AAAA records pointing to this server."
    exit 1
fi

DOMAIN="$1"

# ---------------------------------------------------------------------------
# Create Nginx config
# ---------------------------------------------------------------------------
echo "[1/3] Creating Nginx configuration..."

cat > /etc/nginx/sites-available/blockbook <<EOF
# Blockbook Multi-Coin Nginx Configuration
# Generated: $(date)

# Upstream servers
upstream blockbook_bitcoin {
    server 127.0.0.1:9130;
}
upstream blockbook_litecoin {
    server 127.0.0.1:9131;
}
upstream blockbook_bcash {
    server 127.0.0.1:9132;
}
upstream blockbook_dash {
    server 127.0.0.1:9133;
}
upstream blockbook_zcash {
    server 127.0.0.1:9134;
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL certificates (certbot will populate these)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # SSL hardening
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Proxy settings
    proxy_http_version 1.1;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    # Bitcoin
    location /btc/ {
        proxy_pass https://blockbook_bitcoin/;
        proxy_ssl_verify off;
    }

    # Litecoin
    location /ltc/ {
        proxy_pass https://blockbook_litecoin/;
        proxy_ssl_verify off;
    }

    # Bitcoin Cash
    location /bch/ {
        proxy_pass https://blockbook_bcash/;
        proxy_ssl_verify off;
    }

    # Dash
    location /dash/ {
        proxy_pass https://blockbook_dash/;
        proxy_ssl_verify off;
    }

    # Zcash
    location /zec/ {
        proxy_pass https://blockbook_zcash/;
        proxy_ssl_verify off;
    }

    # Root: redirect to status or a landing page
    location / {
        return 200 'Blockbook Multi-Coin Node\nCoins: /btc, /ltc, /bch, /dash, /zec\n';
        add_header Content-Type text/plain;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/blockbook /etc/nginx/sites-enabled/blockbook
rm -f /etc/nginx/sites-enabled/default

nginx -t

# ---------------------------------------------------------------------------
# Obtain SSL certificate
# ---------------------------------------------------------------------------
echo ""
echo "[2/3] Obtaining SSL certificate for $DOMAIN..."

# Ensure certbot is installed
if ! command -v certbot &> /dev/null; then
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Obtain certificate (non-interactive)
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN" || {
    echo "WARNING: certbot failed. Check DNS records for $DOMAIN"
    echo "You can retry later with: certbot --nginx -d $DOMAIN"
}

# ---------------------------------------------------------------------------
# Restart Nginx
# ---------------------------------------------------------------------------
echo ""
echo "[3/3] Restarting Nginx..."
systemctl restart nginx
systemctl enable nginx

echo ""
echo "=========================================="
echo "  Nginx + SSL Setup Complete!"
echo "=========================================="
echo ""
echo "API Endpoints:"
echo "  https://$DOMAIN/btc/api/v2    (Bitcoin)"
echo "  https://$DOMAIN/ltc/api/v2    (Litecoin)"
echo "  https://$DOMAIN/bch/api/v2    (Bitcoin Cash)"
echo "  https://$DOMAIN/dash/api/v2   (Dash)"
echo "  https://$DOMAIN/zec/api/v2    (Zcash)"
echo ""
echo "SSL auto-renewal is configured via certbot systemd timer."
