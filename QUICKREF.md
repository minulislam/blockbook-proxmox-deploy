# Blockbook Multi-Coin Deployment — Quick Reference Card

## One-Liners

```bash
# Full deployment (run each step)
cd /opt/coins/build/blockbook && bash scripts/01-system-prep.sh
bash scripts/02-build-blockbook.sh
bash scripts/03-install-coins.sh
bash scripts/04-firewall.sh
bash scripts/05-nginx-ssl.sh your-domain.com

# Or use the interactive quickstart
bash quickstart.sh
```

## Service Management

```bash
# All blockbook services
systemctl {start|stop|restart|status} blockbook-{bitcoin,litecoin,bcash,dash,zcash}

# All backend nodes
systemctl {start|stop|restart|status} backend-{bitcoin,litecoin,bcash,dash,zcash}

# Logs
journalctl -u blockbook-bitcoin -f        # live blockbook logs
journalctl -u backend-bitcoin -f          # live backend logs
journalctl -u blockbook-bitcoin --since "1 hour ago"
```

## API Endpoints (if using Nginx)

| Coin | Endpoint |
|------|----------|
| Bitcoin | `https://your-domain.com/btc/api/v2` |
| Litecoin | `https://your-domain.com/ltc/api/v2` |
| Bitcoin Cash | `https://your-domain.com/bch/api/v2` |
| Dash | `https://your-domain.com/dash/api/v2` |
| Zcash | `https://your-domain.com/zec/api/v2` |

## Direct API Endpoints (local)

| Coin | URL |
|------|-----|
| Bitcoin | `https://localhost:9130/api/v2` |
| Litecoin | `https://localhost:9131/api/v2` |
| BCH | `https://localhost:9132/api/v2` |
| Dash | `https://localhost:9133/api/v2` |
| Zcash | `https://localhost:9134/api/v2` |

> Note: Blockbook uses self-signed certs by default. Use `-k` with curl or accept the certificate in your browser.

## Useful API Calls

```bash
# Status check
curl -sk https://localhost:9130/api/v2 | jq

# Get block by height
curl -sk https://localhost:9130/api/v2/block/800000 | jq

# Get transaction
curl -sk https://localhost:9130/api/v2/tx/TXID_HERE | jq

# Get address balance & txs
curl -sk "https://localhost:9130/api/v2/address/ADDRESS_HERE?page=1&pageSize=10" | jq

# Get xpub info
curl -sk "https://localhost:9130/api/v2/xpub/XPUB_HERE?tokens=derived" | jq

# Send tx (if enabled)
curl -sk -X POST https://localhost:9130/api/v2/sendtx/RAW_TX_HEX

# Estimate fee
curl -sk "https://localhost:9130/api/v2/estimatefee/6" | jq

# Fiat rates
curl -sk "https://localhost:9130/api/v2/tickers" | jq
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| OOM during sync | Add `-workers=1 -dbcache=0` to blockbook service, restart |
| DB corrupt/inconsistent | `rm -rf /opt/coins/data/*/blockbook/*` + restart service |
| Backend RPC unreachable | Check `systemctl status backend-*`, check ports with `ss -tlnp` |
| Sync extremely slow | Ensure NVMe SSD, check `iotop`, add RAM |
| Port already in use | `lsof -i :PORT` to find conflicting process |
| "not-found" service | Package install may have used different names; check `systemctl list-unit-files \| grep -E "(blockbook\|backend)"` |

## File Locations

| Data | Path |
|------|------|
| Backend data | `/opt/coins/data/<coin>/backend/` |
| Blockbook index | `/opt/coins/data/<coin>/blockbook/` |
| Backend binaries | `/opt/coins/nodes/<coin>/bin/` |
| Blockbook binaries | `/opt/coins/blockbook/<coin>/bin/` |
| Configs | `/opt/coins/nodes/<coin>/*.conf`, `/opt/coins/blockbook/<coin>/*.json` |
| Logs | `journalctl -u <service>` |

## Backup

```bash
# IMPORTANT: Back up while services are STOPPED, or use --repair flag
# Backend data (can be copied live with -dbshutdown or using backup tools)
rsync -avP --delete /opt/coins/data/bitcoin/backend/ /backup/bitcoin-backend/

# Blockbook index (must be stopped)
systemctl stop blockbook-bitcoin
rsync -avP --delete /opt/coins/data/bitcoin/blockbook/ /backup/bitcoin-blockbook/
systemctl start blockbook-bitcoin
```

## Restart All (e.g. after reboot)

```bash
for c in bitcoin litecoin bcash dash zcash; do
    systemctl restart backend-$c blockbook-$c
done
```

## Check Sync Progress (all coins)

```bash
bash scripts/status.sh
```
