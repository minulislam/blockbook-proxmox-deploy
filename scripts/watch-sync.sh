#!/bin/bash
# =============================================================================
# watch-sync.sh — Watch sync progress for a specific coin
# =============================================================================
# Usage: ./watch-sync.sh <coin>   (bitcoin|litecoin|bcash|dash|zcash)

COIN=${1:-bitcoin}

# Port mapping
declare -A PORTS=(
    [bitcoin]=9130
    [litecoin]=9131
    [bcash]=9132
    [dash]=9133
    [zcash]=9134
)

PORT=${PORTS[$COIN]:-9130}

echo "Watching $COIN sync progress on port $PORT..."
echo "Press Ctrl+C to stop."
echo ""

while true; do
    resp=$(curl -s --max-time 5 "http://127.0.0.1:$PORT/api/v2" 2>/dev/null)
    if [ -n "$resp" ]; then
        inSync=$(echo "$resp" | jq -r '.blockbook.inSync')
        bestHeight=$(echo "$resp" | jq -r '.blockbook.bestHeight')
        backendBlocks=$(echo "$resp" | jq -r '.backend.blocks')
        lastBlockTime=$(echo "$resp" | jq -r '.blockbook.lastBlockTime')

        printf "\r[$(date +%H:%M:%S)] %-10s | Sync: %-5s | BB: %-9s | Node: %-9s | Last: %s" \
            "$COIN" "$inSync" "$bestHeight" "$backendBlocks" "$lastBlockTime"
    else
        printf "\r[$(date +%H:%M:%S)] %-10s | API UNREACHABLE on port %s                    " \
            "$COIN" "$PORT"
    fi
    sleep 5
done
