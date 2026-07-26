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

do following on server and each client...

```bash
sudo pacman -S wireguard-tools
```

restrict access of new files to only the owner, generate private key and put in file, and then use that to gen public key:

```bash
umask 077
wg genkey > ~/.wg-private.key
wg pubkey < ~/.wg-private.key > ~/.wg-public.key
```

pick an internal (LAN) subnet for the tunnel (just use 192.168.2.0/24 and give each peer a unique address in that subnet by incrementing the last octet (192.168.2.1, 192.168.2.2, etc)). this subnet is used for both the server and each client

the following can be used to check what subnets are taken but currently 192.168.2.0/24 is unused so these docs will use that:

```bash
ip -4 addr show
ip -4 route show
```

on server create `/etc/wireguard/wg0.conf`

```ini
[Interface]
Address = 192.168.2.1/24
ListenPort = 51820
PrivateKey = <contents of server ~/.wg-private.key>

[Peer]
PublicKey = <contents of client ~/.wg-public.key>
AllowedIPs = 192.168.2.2/32
```

now need to assign static ip to the homelab sever box in router settings

find mac address of homelab server:

```bash
ip link show
```

look for the bridged network and the `aa:bb:cc:dd:ee:ff` is the MAC address for the interface

in the DHCP section of the router, assign a static IP to the device with the MAC address found above

also add a static IP to the Home assistant interface while we're at it

now find the router public ip:

```bash
curl -4 ifconfig.me
```

Go to the NAT/PAT router settings and create a new port forwarding rule with the following settings:

- Protocol name (if asked): (custom) `WireGuard`
- Internal port: `51820`
- External port: `51820`
- Protocol: `UDP`
- Target: the homelab interface we assigned a static IP to above

if the ISP is setting CGNAT, disable it to prevent sharing public ipv4s with others

on client create `/etc/wireguard/wg0.conf`

```bash
[Interface]
Address = 192.168.2.2/24
PrivateKey = <contents of client ~/.wg-private.key>

[Peer]
PublicKey = <contents of server ~/.wg-public.key>
Endpoint = <router public IP discovered above>:51820
AllowedIPs = 192.168.2.1/32, 192.168.1.0/24
```

create interfaces

on server:

```bash
sudo ip link add dev wg0 type wireguard
sudo ip address add dev wg0 192.168.2.1/24
```

on client:

```bash
sudo ip link add dev wg0 type wireguard
sudo ip address add dev wg0 192.168.2.2/24
```

Bring the interfaces up on both server and clients:

```bash
sudo wg-quick up wg0
```

Enable WireGuard to start on boot:

```bash
sudo systemctl enable wg-quick@wg0
```

### Enable IP Forwarding (Server Only)

Allow the server to forward traffic between the tunnel and the LAN:

```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf
```

### Set Up Source NAT (Server Only)

Rewrite the source IP of tunnel traffic so home LAN services know how to reply back. Without this, devices on the LAN receive packets from `192.168.2.x` and try to reply directly, but the router has no route back to that subnet.

```bash
sudo iptables -t nat -A POSTROUTING -o br0 -j MASQUERADE
```

Make this persistent across reboots:

```bash
cat <<'EOF' | sudo tee /etc/iptables/iptables.rules > /dev/null
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o br0 -j MASQUERADE
COMMIT
EOF
sudo systemctl enable --now iptables.service
```

### Test the Connection

```bash
ping 192.168.2.1
curl http://192.168.1.21:8123
```

## Expose Ollama on LAN from the PC

Ollama binds to `127.0.0.1` by default. Set `OLLAMA_HOST=0.0.0.0` to make it reachable from other devices:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '[Service]\nEnvironment="OLLAMA_HOST=0.0.0.0"\nEnvironment="OLLAMA_CONTEXT_LENGTH=32768"\n' | sudo tee /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl enable --now ollama
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
