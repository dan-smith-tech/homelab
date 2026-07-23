#!/bin/bash

set -euo pipefail

# set hostname
read -r -p "Hostname [nilfgaard]: " HOSTNAME
sudo hostnamectl set-hostname "${HOSTNAME:-novigrad}"

# install yay
tmpdir="$(mktemp -d)"
cd "$tmpdir"
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd "$HOME"
rm -rf "$tmpdir"

# install packages
sudo pacman -S --noconfirm kitty neovim
yay -S --noconfirm brave-bin

echo "Automated setup complete. Continue with manual configuration detailed in \`configure.md\`."
