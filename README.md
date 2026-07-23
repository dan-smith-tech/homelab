# My Arch Linux Setup

I value simplicity and minimalism. Even as a computer scientist, I use as little software as possible. I want my operating system to be lightweight and performant, free from bloatware, telemetry and spyware, or unnecessary features. Full configurability and complete control over my system are essential to me. Therefore, I exclusively use [Arch Linux](https://archlinux.org/).

My installation process is automated by two scripts: `install` and `configure`. The `install` script performs an installation of Arch Linux with a zero-bloat base KDE Plasma install, and the `configure` script installs and sets up the services I host on my local network.

## Pre-installation

1. Flash the [Arch Linux ISO](https://www.archlinux.org/download/) to a USB drive.

1. Insert the USB drive into the computer and boot into it via the BIOS boot menu.

1. Enter the Arch Linux live environment.

1. If using a wireless network, connect to it over WiFi:

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

1. Make the script executable:

   ```bash
   chmod +x install.sh
   ```

1. Run the `install` script:

   ```bash
   ./install.sh
   ```

1. Follow the prompts. The system will automatically reboot when the installation is complete.

## Post-installation

9. Login and, if using a wireless network, connect to it over WiFi:

   ```bash
   nmcli device wifi connect <network> --ask
   ```

1. Get the IP address of the server:

   ```bash
   ip a
   ```

   Look for the local LAN address (192.168.x.x or 10.x.x.x).

1. Remote into the server over the local network:

   ```bash
   ssh dan@<ip>
   ```

1. On a client device...

   Create the SSH daemon drop-in directory:

   ```bash
   sudo mkdir -p /etc/ssh/sshd_config.d
   ```

   Write the key-only SSH configuration:

   ```bash
   sudo tee /etc/ssh/sshd_config.d/99-key-only.conf > /dev/null << 'SSHEOF'
   PasswordAuthentication no
   KbdInteractiveAuthentication no
   PubkeyAuthentication yes
   SSHEOF
   ```

   Reload `sshd`:

   ```bash
   sudo systemctl reload sshd
   ```

   Add a host config to `~/.ssh/config`:

   ```ssh-config
   Host homelab
   HostName 192.168.x.x
   User dan
   IdentityFile ~/.ssh/id_ed25519
   ```

   Copy the public key:

   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

1. On the server, create the SSH directory and paste the public key into `~/.ssh/authorized_keys`:

   ```bash
   mkdir -p ~/.ssh
   ```

1. Run the `configure` script:

   ```bash
   ./configure.sh [--work]
   ```

1. Follow the prompts. The system will automatically reboot when the configuration is complete.
