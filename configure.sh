#!/bin/bash

set -euo pipefail

# set hostname
sudo hostnamectl set-hostname nilfgaard

# install yay
tmpdir="$(mktemp -d)"
cd "$tmpdir"
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd "$HOME"
rm -rf "$tmpdir"

# install packages
sudo pacman -S egl-wayland kitty plasma-desktop qemu virt-install
yay -S --noconfirm brave-bin

# home assistant install
VM_NAME="haos"
VM_DESCRIPTION="Home Assistant OS"
VM_RAM="8192"
VM_VCPUS="4"
WORKDIR="/var/lib/libvirt/images/haos"
COMPRESSED_IMAGE="${WORKDIR}/haos.qcow2.xz"
QCOW2_IMAGE="${WORKDIR}/haos.qcow2"
HAOS_IMAGE_URL="$(curl -fsSL https://api.github.com/repos/home-assistant/operating-system/releases/latest \
  | grep '"browser_download_url"' \
  | grep 'haos_ova-' \
  | grep '\.qcow2\.xz' \
  | cut -d '"' -f 4 \
  | head -n1)"
sudo mkdir -p "$WORKDIR"
sudo curl -fL "$HAOS_IMAGE_URL" -o "$COMPRESSED_IMAGE"
sudo xz -dkf "$COMPRESSED_IMAGE"
sudo rm -f "$COMPRESSED_IMAGE"
sudo systemctl enable --now libvirtd
sudo virt-install \
  --name "$VM_NAME" \
  --description "$VM_DESCRIPTION" \
  --os-variant=generic \
  --virt-type kvm \
  --ram="$VM_RAM" \
  --vcpus="$VM_VCPUS" \
  --disk "${QCOW2_IMAGE},bus=scsi" \
  --controller type=scsi,model=virtio-scsi \
  --network bridge=br0,model=virtio \
  --import \
  --graphics none \
  --boot uefi
