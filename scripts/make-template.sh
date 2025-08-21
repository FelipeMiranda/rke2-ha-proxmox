#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────────────────────────────────────────────────────────────
# Proxmox: Create a cloud-init VM and convert it into a template
# Example:
#   ./make-template.sh \
#     -i 9000 -n "debian-12-cloudinit" -I /isos/debian-12-genericcloud-amd64.qcow2 \
#     -s local-zfs -m 2048 -c 2 -b vmbr0 --ci-user debian --ssh-key ~/.ssh/id_rsa.pub --uefi
# ────────────────────────────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
Usage:
  make-template.sh -i <vmid> -n <name> -I <cloud-image> -s <storage> [options]

Required:
  -i, --id <vmid>            VM ID (e.g., 9000)
  -n, --name <name>          VM name (e.g., debian-12-cloudinit)
  -I, --image <path|URL>     Cloud image (qcow2/raw). Local path or HTTP(S) URL.
  -s, --storage <name>       Proxmox storage name to hold disks (e.g., local-zfs)

Options:
  -m, --memory <MB>          Memory MB (default: 1024)
  -c, --cores <N>            vCPU cores (default: 1)
  -b, --bridge <vmbrX>       Bridge for net0 (default: vmbr0)
      --disk-format <fmt>    Import format: qcow2|raw (default: qcow2)
      --ci-user <user>       cloud-init default user (optional)
      --ssh-key <file>       Inject SSH public key from file (optional)
      --ip <cfg>             cloud-init ipconfig0 (e.g., "dhcp" or "192.168.1.10/24,gw=192.168.1.1")
      --uefi                 Use OVMF + EFI disk (default: BIOS/SeaBIOS)
      --help                 Show this help

Notes:
- Requires: qm, pvesm, (curl if --image is a URL)
- Automatically picks the correct imported disk volume from 'unused0'.
- Leaves a template VM ready to clone.
EOF
}

# ── Defaults
MEMORY=1024
CORES=1
BRIDGE="vmbr0"
DISK_FORMAT="qcow2"
USE_UEFI=false
CI_USER=""
SSH_KEY_FILE=""
IPCONFIG0=""

# ── Parse args
VMID=""
NAME=""
IMAGE=""
STORAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--id) VMID="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    -I|--image) IMAGE="$2"; shift 2 ;;
    -s|--storage) STORAGE="$2"; shift 2 ;;
    -m|--memory) MEMORY="$2"; shift 2 ;;
    -c|--cores) CORES="$2"; shift 2 ;;
    -b|--bridge) BRIDGE="$2"; shift 2 ;;
    --disk-format) DISK_FORMAT="$2"; shift 2 ;;
    --ci-user) CI_USER="$2"; shift 2 ;;
    --ssh-key) SSH_KEY_FILE="$2"; shift 2 ;;
    --ip) IPCONFIG0="$2"; shift 2 ;;
    --uefi) USE_UEFI=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Validate required
[[ -n "$VMID" && -n "$NAME" && -n "$IMAGE" && -n "$STORAGE" ]] || { usage; exit 1; }

# ── Check deps
command -v qm >/dev/null || { echo "Error: qm not found."; exit 1; }
command -v pvesm >/dev/null || { echo "Error: pvesm not found."; exit 1; }

TEMP_IMG=""
cleanup() { [[ -n "$TEMP_IMG" && -f "$TEMP_IMG" ]] && rm -f "$TEMP_IMG"; }
trap cleanup EXIT

# ── If IMAGE is a URL, download it
if [[ "$IMAGE" =~ ^https?:// ]]; then
  command -v curl >/dev/null || { echo "Error: curl required to download image URL."; exit 1; }
  TEMP_IMG="$(mktemp --suffix=.img)"
  echo "Downloading image to $TEMP_IMG ..."
  curl -L --fail --retry 3 -o "$TEMP_IMG" "$IMAGE"
  IMAGE="$TEMP_IMG"
fi

# ── Prevent accidental overwrite
if qm status "$VMID" &>/dev/null; then
  echo "Error: VMID $VMID already exists. Aborting."
  exit 1
fi

echo "Creating VM $VMID ($NAME) ..."
qm create "$VMID" \
  --name "$NAME" \
  --memory "$MEMORY" \
  --cores "$CORES" \
  --cpu host \
  --balloon 0 \
  --machine q35 \
  --net0 "virtio,bridge=${BRIDGE}" \
  --ostype l26 \
  --hotplug disk,network,usb,memory,cpu \
  --tablet 0 \
  --scsihw virtio-scsi-single

# ── Optional: UEFI (OVMF) with EFI disk; otherwise BIOS
if $USE_UEFI; then
  # Create an EFI disk with enrolled keys so Secure Boot works out-of-the-box
  qm set "$VMID" --bios ovmf --efidisk0 "${STORAGE}:0,pre-enrolled-keys=1"
fi

# ── Import cloud image as a disk (unused0). Prefer qcow2 for space efficiency.
echo "Importing disk ..."
qm importdisk "$VMID" "$IMAGE" "$STORAGE" --format "$DISK_FORMAT"

# ── Find the imported volume from 'unused0'
DISK_VOL="$(qm config "$VMID" | sed -n 's/^unused0: //p' | head -n1)"
if [[ -z "$DISK_VOL" ]]; then
  echo "Error: Could not detect imported disk (unused0)."
  exit 1
fi

# ── Attach as scsi0, mark as bootdisk
qm set "$VMID" --scsi0 "$DISK_VOL",discard=on,ssd=1,iothread=1,aio=io_uring,cache=none,detect_zeroes=on
qm set "$VMID" --boot order=scsi0

# ── Add cloud-init drive
qm set "$VMID" --ide2 "${STORAGE}:cloudinit"

# ── Enable QEMU guest agent (recommended for cloud images)
qm set "$VMID" --agent enabled=1,fstrim_cloned_disks=1

# ── Serial console for cloud images (many expect this)
qm set "$VMID" --serial0 socket --vga virtio

# ── Cloud-init settings (optional)
if [[ -n "$CI_USER" ]]; then
  qm set "$VMID" --ciuser "$CI_USER"
fi

if [[ -n "$SSH_KEY_FILE" ]]; then
  [[ -f "$SSH_KEY_FILE" ]] || { echo "Error: SSH key file not found: $SSH_KEY_FILE"; exit 1; }
  qm set "$VMID" --sshkeys "$SSH_KEY_FILE"
fi

if [[ -n "$IPCONFIG0" ]]; then
  qm set "$VMID" --ipconfig0 "$IPCONFIG0"
fi

# ── Convert into a template
qm template "$VMID"

echo "Template ready: VMID $VMID ($NAME) on storage '$STORAGE'."
