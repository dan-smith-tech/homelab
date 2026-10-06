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

Log in and replace the wired interface with a bridge for port forwarding:

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

## Set up Services

Run the `configure` script:

```bash
curl -O https://raw.githubusercontent.com/dan-smith-tech/homelab/main/configure.sh
chmod +x configure.sh
./configure.sh
```

Follow the prompts. The system will automatically reboot when the configuration is complete.

## Set up VPN

Install WireGuard on server and clients:

```bash
sudo pacman -S wireguard-tools
```

Generate keys:

```bash
umask 077
wg genkey > ~/.wg-private.key
wg pubkey < ~/.wg-private.key > ~/.wg-public.key
```

**Router Configuration**

1.  **Disable CGN**: Ensure you have a dedicated public IP. Disable "Carrier-Grade NAT" or "Large Scale NAT" in your router settings.
2.  **Static IP**: Assign a static LAN IP to the homelab server.
3.  **DynDNS (No-IP)**:
    - Create a free account at [No-IP](https://www.noip.com).
    - Add a hostname record (e.g., `myhomelab.ddns.net`) and **enable Dynamic DNS**.
    - In your router's DynDNS tab, set service to No-IP, enter your hostname, username, and password.
4.  **Port Forwarding**: Add a NAT/PAT rule to the router:
    - Internal/External Port: `51820`
    - Protocol: `UDP`
    - Target: Server static LAN IP

**Server Configuration**

Create `/etc/wireguard/wg0.conf`:

```ini
[Interface]
Address = 192.168.2.1/24
ListenPort = 51820
PrivateKey = <contents of server ~/.wg-private.key>

[Peer]
PublicKey = <contents of client ~/.wg-public.key>
AllowedIPs = 192.168.2.2/32
```

**Client Configuration**

Create `/etc/wireguard/wg0.conf`:

```ini
[Interface]
Address = 192.168.2.2/24
PrivateKey = <contents of client ~/.wg-private.key>

[Peer]
PublicKey = <contents of server ~/.wg-public.key>
Endpoint = <your-noip-hostname>.ddns.net:51820
AllowedIPs = 192.168.2.1/32, 192.168.1.0/24
```

**Startup & Routing**

Start WireGuard and enable on boot:

```bash
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
```

On the server, enable IP forwarding:

```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf
```

Setup NAT so LAN devices can reply to tunnel traffic:

```bash
sudo iptables -t nat -A POSTROUTING -o br0 -j MASQUERADE
```

Persist NAT rules across reboots:

```bash
cat <<'EOF' | sudo tee /etc/iptables/iptables.rules > /dev/null
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o br0 -j MASQUERADE
COMMIT
EOF
sudo systemctl enable --now iptables.service
```

**Test**

From a remote client, verify tunnel and LAN access:

```bash
ping 192.168.2.1
curl http://192.168.1.21:8123
```

## Expose Ollama on LAN from the PC

Ollama binds to `127.0.0.1` by default. The system service (`ollama.service`) runs as a dedicated `ollama` user at boot — no user login or kwallet unlock is required.

Set `OLLAMA_HOST=0.0.0.0` via a systemd drop-in override so it survives reboots:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf <<EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_CONTEXT_LENGTH=32768"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verify it's listening on all interfaces:

```bash
ss -tlnp | grep 11434
```

You want `*:11434`, not `127.0.0.1:11434`.

Find your PC's LAN IP with `ip addr show` (look for the `inet` line under `eno1`). Then from another device on the same network, test:

```bash
curl http://<your-pc-ip>:11434/api/tags
```

## Home Assistant Wake on LAN

Enable in BIOS (Advanced -> APM COnfiguration -> Power On by PCI-E)

Find PC MAC address:

```bash
ip link show
```
