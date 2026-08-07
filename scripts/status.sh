#!/bin/bash
# =============================================================================
# status.sh — Quick status check for all Blockbook coins
# =============================================================================

echo "============================================"
echo "  Blockbook Multi-Coin Node Status"
echo "  $(date)"
echo "============================================"
echo ""

# Coin definitions: name, public_port, backend_service, blockbook_service
declare -a COINS=(
    "Bitcoin:9130:backend-bitcoin:blockbook-bitcoin"
    "Litecoin:9131:backend-litecoin:blockbook-litecoin"
    "Bitcoin Cash:9132:backend-bcash:blockbook-bcash"
    "Dash:9133:backend-dash:blockbook-dash"
    "Zcash:9134:backend-zcash:blockbook-zcash"
)

for coin_def in "${COINS[@]}"; do
    IFS=':' read -r NAME PORT BACKEND_SERVICE BLOCKBOOK_SERVICE <<< "$coin_def"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Backend service status
    backend_status=$(systemctl is-active "$BACKEND_SERVICE" 2>/dev/null || echo "not-found")
    backend_sub=$(systemctl is-enabled "$BACKEND_SERVICE" 2>/dev/null || echo "unknown")
    echo "  Backend:  $backend_status ($backend_sub)"

    # Blockbook service status
    bb_status=$(systemctl is-active "$BLOCKBOOK_SERVICE" 2>/dev/null || echo "not-found")
    bb_sub=$(systemctl is-enabled "$BLOCKBOOK_SERVICE" 2>/dev/null || echo "unknown")
    echo "  Blockbook: $bb_status ($bb_sub)"

    # API status
    api_resp=$(curl -s --max-time 3 "http://127.0.0.1:$PORT/api/v2" 2>/dev/null)
    if [ -n "$api_resp" ]; then
        inSync=$(echo "$api_resp" | jq -r '.blockbook.inSync // "unknown"')
        bestHeight=$(echo "$api_resp" | jq -r '.blockbook.bestHeight // "unknown"')
        backendBlocks=$(echo "$api_resp" | jq -r '.backend.blocks // "unknown"')
        mempoolSize=$(echo "$api_resp" | jq -r '.blockbook.mempoolSize // "unknown"')
        dbSize=$(echo "$api_resp" | jq -r '.blockbook.dbSize // "unknown"')

        echo "  In Sync:      $inSync"
        echo "  BB Height:    $bestHeight"
        echo "  Node Height:  $backendBlocks"
        echo "  Mempool:      $mempoolSize"
        echo "  DB Size:      $dbSize bytes"
    else
        echo "  API:          UNREACHABLE (port $PORT)"
    fi
    echo ""
done

echo "============================================"
echo "  Disk Usage"
echo "============================================"
df -h /opt/coins/data/ 2>/dev/null || df -h /
echo ""

echo "============================================"
echo "  Memory Usage"
echo "============================================"
free -h
echo ""

echo "============================================"
echo "  Top CPU Processes"
echo "============================================"
ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -10
