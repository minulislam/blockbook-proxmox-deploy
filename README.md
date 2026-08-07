# Blockbook Multi-Coin Proxmox Deployment Guide

Complete deployment package for running **Trezor Blockbook** with **Bitcoin, Litecoin, Bitcoin Cash, Dash, and Zcash** on a Proxmox VE server.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Proxmox VE Host                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         Debian 12 VM (64GB RAM, 1TB+ NVMe SSD)      │   │
│  │                                                     │   │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐      │   │
│  │  │ bitcoind │◄──►│ blockbook│◄──►│  Nginx   │◄────┼───┼──► HTTPS :443
│  │  │ :8332    │    │  :9130   │    │  :80/443 │      │   │
│  │  └──────────┘    └──────────┘    └──────────┘      │   │
│  │  ┌──────────┐    ┌──────────┐                       │   │
│  │  │litecoind │◄──►│ blockbook│◄──►                   │   │
│  │  │ :9332    │    │  :9131   │                       │   │
│  │  └──────────┘    └──────────┘                       │   │
│  │  ┌──────────┐    ┌──────────┐                       │   │
│  │  │  bcashd  │◄──►│ blockbook│◄──►                   │   │
│  │  │ :8334    │    │  :9131   │                       │   │
│  │  └──────────┘    └──────────┘                       │   │
│  │  ┌──────────┐    ┌──────────┐                       │   │
│  │  │  dashd   │◄──►│ blockbook│◄──►                   │   │
│  │  │ :9998    │    │  :9132   │                       │   │
│  │  └──────────┘    └──────────┘                       │   │
│  │  ┌──────────┐    ┌──────────┐                       │   │
│  │  │ zcashd   │◄──►│ blockbook│◄──►                   │   │
│  │  │ :8232    │    │  :9133   │                       │   │
│  │  └──────────┘    └──────────┘                       │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Proxmox VM Specs

Create a single VM with these specs (all coins on one machine):

| Resource | Recommendation |
|----------|----------------|
| **OS** | Debian 12 (bookworm) amd64 |
| **CPU** | 16+ cores (Intel/AMD x86_64) |
| **RAM** | 64 GB (32 GB minimum for BTC alone; 64 GB for all 5) |
| **Disk** | 1.5 TB NVMe SSD (minimum 1 TB) |
| **Network** | Bridged (vmbr0) with static IP |

### Disk Breakdown (estimated)

| Coin | Backend Data | Blockbook Index | Total |
|------|-------------|-----------------|-------|
| Bitcoin | ~650 GB | ~200 GB | ~850 GB |
| Litecoin | ~120 GB | ~40 GB | ~160 GB |
| Bitcoin Cash | ~250 GB | ~80 GB | ~330 GB |
| Dash | ~30 GB | ~10 GB | ~40 GB |
| Zcash | ~50 GB | ~15 GB | ~65 GB |
| **Total** | | | **~1.45 TB** |

> **Note:** Use **ZFS** or **thin-provisioned LVM** on Proxmox. All data should live on fast NVMe SSD — HDD is not recommended for initial sync.

---

## Deployment Steps (Quick Reference)

```bash
# 1. On Proxmox: Create the VM (see docs/proxmox-vm-setup.md)

# 2. On the VM: Run the setup pipeline
bash scripts/01-system-prep.sh        # Update, deps, Docker, swap
bash scripts/02-build-blockbook.sh    # Build all .deb packages
bash scripts/03-install-coins.sh      # Install backend + blockbook for each coin
bash scripts/04-firewall.sh           # Configure UFW
bash scripts/05-nginx-ssl.sh          # Nginx reverse proxy + SSL (optional)
```

---

## Port Assignments

| Coin | Backend RPC | Blockbook Internal | Blockbook Public | ZMQ |
|------|------------|--------------------|------------------|-----|
| Bitcoin | 8030 | 9030 | 9130 | 28330 |
| Litecoin | 8031 | 9031 | 9131 | 28331 |
| Bitcoin Cash | 8032 | 9032 | 9132 | 28332 |
| Dash | 8033 | 9033 | 9133 | 28333 |
| Zcash | 8034 | 9034 | 9134 | 28334 |

> Internal ports are for Blockbook ↔ backend communication only. Public ports are what Nginx proxies to (or exposed directly).

---

## File Structure

```
blockbook-proxmox-deploy/
├── README.md                          # This file
├── scripts/
│   ├── 01-system-prep.sh              # System preparation
│   ├── 02-build-blockbook.sh          # Build Debian packages
│   ├── 03-install-coins.sh            # Install all coins
│   ├── 04-firewall.sh                 # UFW rules
│   └── 05-nginx-ssl.sh                # Nginx + SSL setup
├── configs/
│   ├── nginx-blockbook.conf           # Nginx reverse proxy config
│   └── backend-override.json          # Optional backend config overrides
├── systemd/
│   ├── bitcoin-backend.service        # bitcoind systemd unit
│   ├── bitcoin-blockbook.service      # blockbook-bitcoin unit
│   ├── litecoin-backend.service       # litecoind unit
│   ├── litecoin-blockbook.service     # blockbook-litecoin unit
│   ├── bch-backend.service            # bcashd unit
│   ├── bch-blockbook.service          # blockbook-bcash unit
│   ├── dash-backend.service           # dashd unit
│   ├── dash-blockbook.service         # blockbook-dash unit
│   ├── zcash-backend.service          # zcashd unit
│   └── zcash-blockbook.service        # blockbook-zcash unit
└── docs/
    └── proxmox-vm-setup.md            # Detailed Proxmox VM creation guide
```

---

## System Requirements Checklist

Before starting, ensure:

- [ ] Proxmox VE 7.x or 8.x installed and accessible
- [ ] Static IP available for the VM
- [ ] Domain name pointing to the VM (for SSL; optional)
- [ ] NVMe SSD storage available in Proxmox
- [ ] At least 64 GB RAM available on host
- [ ] 1.5 TB+ free disk space on host

---

## Initial Sync Strategy

The first sync will take **days to weeks** depending on your hardware and network.

**Recommended approach:**

1. **Start with Bitcoin first** (largest chain, longest sync time)
2. **Add other coins in parallel** once Bitcoin is running
3. **Use `-workers=1`** during initial sync if you hit memory limits
4. **Monitor with `htop`** and check logs in `/opt/coins/data/*/blockbook/` and `/opt/coins/data/*/backend/`

### Sync Time Estimates (NVMe, 1 Gbps)

| Coin | Initial Sync Time |
|------|-------------------|
| Bitcoin | 3–7 days |
| Litecoin | 12–24 hours |
| Bitcoin Cash | 1–3 days |
| Dash | 6–12 hours |
| Zcash | 12–24 hours |

---

## Monitoring

Check status of any coin:

```bash
# Blockbook status (JSON)
curl -s http://localhost:9130/api/v2 | jq .

# Check if synced
curl -s http://localhost:9130/api/v2 | jq '.blockbook.inSync'

# Backend block count
curl -s http://localhost:9130/api/v2 | jq '.backend.blocks'

# Check services
systemctl status blockbook-bitcoin blockbook-litecoin blockbook-bcash blockbook-dash blockbook-zcash
systemctl status backend-bitcoin backend-litecoin backend-bcash backend-dash backend-zcash
```

---

## Troubleshooting

### Out of Memory During Sync

```bash
# Reduce memory usage during initial sync
sudo systemctl edit --full blockbook-bitcoin
# Add flags: -workers=1 -dbcache=0
```

### Database Corruption ("inconsistent state")

```bash
# Database was corrupted, likely from OOM kill
# Delete blockbook DB and re-sync:
sudo rm -rf /opt/coins/data/bitcoin/blockbook/*
sudo systemctl restart blockbook-bitcoin
```

### Port Conflicts

```bash
# Check what's using a port
sudo ss -tlnp | grep 9130
sudo lsof -i :9130
```

---

## Security Notes

1. **RPC ports (803x)** are bound to `127.0.0.1` by default — never expose them externally
2. **Blockbook public ports (913x)** should be behind Nginx or a firewall
3. **WebSocket origins** are not enforced by default — configure an allowlist if exposed publicly
4. Run `ufw` or `iptables` to restrict access (script `04-firewall.sh` handles this)

---

## Useful Commands

```bash
# View blockbook logs
sudo journalctl -u blockbook-bitcoin -f

# View backend logs
sudo journalctl -u backend-bitcoin -f

# Restart everything for one coin
sudo systemctl restart backend-bitcoin blockbook-bitcoin

# Check disk usage
sudo du -sh /opt/coins/data/*

# Check RAM usage
free -h

# All blockbook statuses
for p in 9130 9131 9132 9133 9134; do
  echo "=== Port $p ==="
  curl -s http://localhost:$p/api/v2 | jq -r '[.blockbook.coin, .blockbook.inSync, .backend.blocks] | @tsv'
done
```

---

## License

These deployment scripts are provided as-is. Blockbook itself is open-source under the original project license at [trezor/blockbook](https://github.com/trezor/blockbook).
