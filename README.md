# My Arch Linux Setup

I value simplicity and minimalism. Even as a computer scientist, I use as little software as possible. I want my operating system to be lightweight and performant, free from bloatware, telemetry and spyware, or unnecessary features. Full configurability and complete control over my system are essential to me. Therefore, I exclusively use [Arch Linux](https://archlinux.org/).

My entire installation process is automated by two scripts: `install` and `configure`. The `install` script performs an  installation of Arch Linux with a zero-bloat base KDE Plasma install, and the `configure` script sets up my preferred software and configurations.

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
   curl -O https://raw.githubusercontent.com/dan-smith-tech/rig/main/install.sh
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

10. Clone this repo:

   ```bash
   git clone https://github.com/dan-smith-tech/rig.git
   ```

11. Run the `configure` script:

   ```bash
   ./configure.sh [--work]
   ```

12. Follow the prompts. The system will automatically reboot when the configuration is complete.
