#!/bin/bash

set -euo pipefail

USERNAME="dan"

# determine install type: laptop gets 8G swap, PC gets NVIDIA/Steam
read -r -p "Installing for laptop or PC? [PC]: " install_type
case "${install_type,,}" in
    laptop) IS_LAPTOP=true ;;
    *) IS_LAPTOP=false ;;
esac

# resolve partition name for nvme/mmcblk vs sdX devices
get_partition() {
    local dev="$1" part="$2"
    if [[ "$dev" =~ ^(nvme|mmcblk) ]]; then
        echo "${dev}p${part}"
    else
        echo "${dev}${part}"
    fi
}

# select and confirm target disk
echo
lsblk
echo
read -r -p "Target device to wipe (e.g. sda, nvme0n1): " TARGET_DEVICE
if [ ! -b "/dev/$TARGET_DEVICE" ]; then
    echo "Error: /dev/$TARGET_DEVICE does not exist"
    exit 1
fi
lsblk "/dev/$TARGET_DEVICE"
echo

# tear down any active LVM/mounts on target device before wiping
vgscan 2>/dev/null || true
vgchange -an vg_system 2>/dev/null || true
vgremove -f vg_system 2>/dev/null || true
while IFS= read -r part; do
    swapoff "/dev/$part" 2>/dev/null || true
    umount -l "/dev/$part" 2>/dev/null || true
done < <(lsblk -ln -o NAME "/dev/$TARGET_DEVICE" | tail -n +2)
sleep 1
partx --delete "/dev/$TARGET_DEVICE" 2>/dev/null || true

sgdisk --zap-all "/dev/$TARGET_DEVICE"

# create GPT partitions: EFI (1G), /boot (1G), LVM (remainder)
parted -s /dev/$TARGET_DEVICE \
    mklabel gpt \
    mkpart primary fat32 1MiB 1GiB \
    mkpart primary ext4 1GiB 2GiB \
    mkpart primary ext4 2GiB 100% \
    set 3 lvm on
sleep 2
partprobe "/dev/$TARGET_DEVICE"
sleep 5

# format partitions and set up LVM volumes
for part in 1 2 3; do
    wipefs -a "/dev/$(get_partition "$TARGET_DEVICE" $part)" 2>/dev/null || true
done
mkfs.fat -F32 "/dev/$(get_partition "$TARGET_DEVICE" 1)"
mkfs.ext4 "/dev/$(get_partition "$TARGET_DEVICE" 2)"
LVM_PART="/dev/$(get_partition "$TARGET_DEVICE" 3)"
dd if=/dev/zero of="$LVM_PART" bs=1M count=100 status=none
wipefs -a "$LVM_PART"
pvcreate --yes --force "$LVM_PART"
vgcreate vg_system "$LVM_PART"
if [ "$IS_LAPTOP" = true ]; then
    lvcreate -L 8G vg_system -n lv_swap
fi
lvcreate -l 100%FREE vg_system -n lv_root
modprobe dm_mod
vgscan
vgchange -ay
mkfs.ext4 /dev/vg_system/lv_root
if [ "$IS_LAPTOP" = true ]; then
    mkswap /dev/vg_system/lv_swap
    swapon /dev/vg_system/lv_swap
fi

# mount root and boot
mount /dev/vg_system/lv_root /mnt
mkdir -p /mnt/boot
mount "/dev/$(get_partition "$TARGET_DEVICE" 2)" /mnt/boot

# bootstrap base system and generate fstab
pacstrap /mnt base
genfstab -U /mnt >> /mnt/etc/fstab

# write and run chroot setup script
cat > /mnt/setup_chroot.sh << EOF
#!/bin/bash

# set root and user passwords
passwd
useradd -m -g users -G tty,input,video,audio,optical,storage,wheel "$USERNAME"
passwd "$USERNAME"

# install packages
pacman -S --noconfirm ark base base-devel bluedevil bluez bluez-utils dolphin efibootmgr git grub gwenview kitty linux linux-firmware linux-headers lvm2 networkmanager okular plasma sudo tesseract tesseract-data-eng

# install GPU drivers and gaming tools (PC) or Intel/audio drivers (laptop)
if [ "$IS_LAPTOP" = false ]; then
    sed -i '/^#\\[multilib\\]/,/^#Include = \\/etc\\/pacman.d\\/mirrorlist/ { s/^#//; }' /etc/pacman.conf
    pacman -Syu --noconfirm
    pacman -S --noconfirm cuda egl-wayland gamescope lib32-nvidia-utils nvidia-container-toolkit nvidia-open nvidia-utils opencl-nvidia steam
else
    pacman -S --noconfirm intel-media-driver mesa sof-firmware vulkan-icd-loader vulkan-intel vulkan-tools
fi

# allow users in wheel group to use sudo
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

# configure mkinitcpio for LVM and regenerate initramfs
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -p linux

# generate locales for GB and US English
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# setup grub with hidden menu and no timeout
mkdir -p /boot/EFI
mount "/dev/$(get_partition "$TARGET_DEVICE" 1)" /boot/EFI
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
mkdir -p /boot/grub/locale
cp /usr/share/locale/en\\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo 2>/dev/null || true
grub-mkconfig -o /boot/grub/grub.cfg

# enable services
systemctl enable sddm.service NetworkManager bluetooth.service

EOF

chmod +x /mnt/setup_chroot.sh
arch-chroot /mnt /setup_chroot.sh
rm /mnt/setup_chroot.sh

# unmount
umount -R /mnt

echo

for i in {3..1}; do
    echo -ne "Rebooting in $i seconds...\r"
    sleep 1
done
echo
reboot
