# My Arch Linux Setup

I value simplicity and minimalism. Even as a computer scientist, I use as little software as possible. I want my operating system to be lightweight and performant, free from bloatware, telemetry and spyware, or unnecessary features. Full configurability and complete control over my system are essential to me. Therefore, I exclusively use [Arch Linux](https://archlinux.org/).

My installation process is automated by two scripts: `install` and `configure`. The `install` script performs an  installation of Arch Linux with a zero-bloat base KDE Plasma install, and the `configure` script installs and sets up the services I host on my local network. 

## Pre-installation

1. Flash the [Arch Linux ISO](https://www.archlinux.org/download/) to a USB drive.

2. Insert the USB drive into the computer and boot into it via the BIOS boot menu.

3. Enter the Arch Linux live environment.

4. If using a wireless network, connect to it over WiFi:

   List available devices:

   ```bash
   iwctl device list
   ```

   Scan for available networks:

   ```bash
   iwctl station <device> scan
   ```

   List available networks:

   ```bash
   iwctl station <device> get-networks
   ```

   Connect to the network:

   ```bash
   iwctl --passphrase <password> station <device> connect <network>
   ```

   Test the connection:

   ```bash
   ping archlinux.org
   ```

## Installation

5. Fetch the `install` script:

   ```bash
   curl -O https://raw.githubusercontent.com/dan-smith-tech/homelab/main/install.sh
   ```

6. Make the script executable:

   ```bash
   chmod +x install.sh
   ```

7. Run the `install` script:

   ```bash
   ./install.sh
   ```

8. Follow the prompts. The system will automatically reboot when the installation is complete.

## Post-installation

9. Login and, if using a wireless network, connect to it over WiFi:

   ```bash
   nmcli device wifi connect <network> --ask
   ```

10. Get the IP address of the server:

    ```bash
    ip a
    ```

    Look for the local LAN address (192.168.x.x or 10.x.x.x).

11. Remote into the server over the local network:

   ```bash
   ssh dan@<ip>
   ```

cat ~/.ssh/id_ed25519.pub on PC

mkdir -p ~/.ssh

nvim ~/.ssh/authorized_keys
paste pub key


back on PC:

sudo mkdir -p /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/99-key-only.conf > /dev/null << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
EOF
sudo systemctl reload sshd

still on PC:

nvim ~/.ssh/config
Host homelab
  HostName 192.168.x.x
  User dan 
  IdentityFile ~/.ssh/id_ed25519


11. Run the `configure` script:

   ```bash
   ./configure.sh [--work]
   ```

12. Follow the prompts. The system will automatically reboot when the configuration is complete.