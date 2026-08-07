# Proxmox VM Setup Guide

## Step 1: Download Debian 12 ISO

In Proxmox shell (on the host):

```bash
cd /var/lib/vz/template/iso/
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.x.x-amd64-netinst.iso
# Or use the latest version from: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/
```

## Step 2: Create the VM

Via Proxmox web UI or CLI:

### Option A: Proxmox Web UI

1. Click **Create VM** (top right)
2. **General**: Name = `blockbook-multicoin`, Start at boot = ✓
3. **OS**: Select the Debian 12 ISO, Type = Linux, Version = 6.x - 2.6 Kernel
4. **System**: Default (SeaBIOS, Default display)
5. **Disks**:
   - Bus/Device = VirtIO Block
   - Storage = your NVMe pool (e.g., `local-zfs` or `nvme-pool`)
   - Disk size = **1500 GB** (1.5 TB)
   - Enable Discard = ✓ (for thin provisioning on SSD)
   - SSD Emulation = ✓
6. **CPU**: Cores = 16, Type = host
7. **Memory**: Memory = 65536 (64 GB)
8. **Network**: Bridge = vmbr0, Model = VirtIO (paravirtualized)
9. Confirm and create

### Option B: Proxmox CLI

```bash
# Adjust these variables
VMID=200
STORAGE=local-zfs  # or your NVMe storage pool
BRIDGE=vmbr0
ISO=/var/lib/vz/template/iso/debian-12.x.x-amd64-netinst.iso

# Create VM
qm create $VMID \
  --name blockbook-multicoin \
  --memory 65536 \
  --cores 16 \
  --cpu host \
  --net0 virtio,bridge=$BRIDGE \
  --scsihw virtio-scsi-single \
  --scsi0 $STORAGE:1500,ssd=1,discard=on \
  --ide2 $STORAGE:iso/$ISO,media=cdrom \
  --boot order=ide2 \
  --ostype l26 \
  --agent enabled=1

# Start VM
qm start $VMID
```

## Step 3: Install Debian 12

Open the VM console and install Debian:

1. **Language**: English
2. **Location**: Your region
3. **Keyboard**: American English (or your layout)
4. **Network**: Configure with a static IP
5. **Hostname**: `blockbook-node`
6. **Domain**: your-domain.com (or leave blank)
7. **Root password**: Set a strong password
8. **User**: Create a non-root user (e.g., `blockbook`)
9. **Partitioning**: Use entire disk → Guided - use entire disk and set up LVM → All files in one partition
   - If you want separate partitions for data, consider:
     - `/` = 100 GB
     - `/opt/coins/data` = remaining space (or mount a second disk here)
10. **Software selection**: ONLY select `SSH server` and `standard system utilities` — deselect desktop environment
11. **GRUB**: Install to `/dev/vda` (or your disk)

After reboot, log in as root or your user.

## Step 4: Post-Install VM Configuration

```bash
# Update system
apt update && apt full-upgrade -y

# Install essential tools
apt install -y sudo curl wget git htop iotop nvme-cli tmux jq net-tools

# Add your user to sudo (if not done during install)
usermod -aG sudo blockbook

# Set timezone
timedatectl set-timezone UTC  # or your timezone: timedatectl list-timezones

# Configure SSH (optional hardening)
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config  # if using keys
systemctl restart ssh

# Increase open files limit (critical for Blockbook)
cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

# Also for systemd services
mkdir -p /etc/systemd/system.conf.d/
cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=65536
EOF
systemctl daemon-reexec

# Reboot to apply all changes
reboot
```

## Step 5: Verify Disk & Mount Points

```bash
# Check available disk space
lsblk
fdisk -l

# Check if /opt/coins/data has enough space
# If you mounted a second disk there:
df -h /opt/coins/data

# If everything is on one partition, ensure root (/) has enough:
df -h /
```

## Step 6: Take a Proxmox Snapshot

Before installing Blockbook, take a clean snapshot:

```bash
# On Proxmox host
qm snapshot $VMID clean-debian-12
```

This gives you a rollback point if anything goes wrong.

---

Next: Run the deployment scripts from the project root.
