# Homelab

I value simplicity and minimalism. Even as a computer scientist, I use as little software as possible. I want my operating system to be lightweight and performant, free from bloatware, telemetry and spyware, or unnecessary features. Full configurability and complete control over my system are essential to me. Therefore, I exclusively use [Arch Linux](https://archlinux.org/).

My installation process is automated by two scripts: `install` and `configure`. The `install` script performs an installation of Arch Linux with a zero-bloat base KDE Plasma install, and the `configure` script installs and sets up the services I host on my local network.

## Install Arch Linux

Flash the [Arch Linux ISO](https://www.archlinux.org/download/) to a USB drive, boot into it via the BIOS boot menu, and run the `install` script:

```bash
curl -O https://raw.githubusercontent.com/dan-smith-tech/homelab/main/install.sh
chmod +x install.sh
./install.sh
```

Follow the prompts. The system will automatically reboot when the installation is complete.

## Set up Network Bridge

Log in and replace the wired interface with a bridge for port forwarding (update `enp4s0` to match your interface):

```bash
sudo nmcli con add type bridge ifname br0 con-name br0 ipv4.method auto ipv6.method ignore
sudo nmcli con add type bridge-slave ifname enp4s0 con-name enp4s0-slave master br0
sudo nmcli con down "Wired connection 1"
sudo nmcli con up enp4s0-slave
sudo nmcli con up br0
```

Get the server's IP address:

```bash
ip a
```

Look for the LAN address (192.168.x.x or 10.x.x.x).

## Prepare SSH on Client

Add a host config to `~/.ssh/config`:

```ssh-config
Host homelab
    HostName 192.168.x.x
    User dan
    IdentityFile ~/.ssh/id_ed25519
```

Copy the public key to the clipboard:

```bash
wl-copy < ~/.ssh/id_ed25519.pub
```

Remote into the server for the first time:

```bash
ssh dan@192.168.x.x
```

## Configure SSH Access on Server

Create the SSH directory and paste the copied key into `~/.ssh/authorized_keys`:

```bash
mkdir -p ~/.ssh
nvim ~/.ssh/authorized_keys
```

## Setup Services

Run the `configure` script:

```bash
curl -O https://raw.githubusercontent.com/dan-smith-tech/homelab/main/configure.sh
chmod +x configure.sh
./configure.sh
```

Follow the prompts. The system will automatically reboot when the configuration is complete.
