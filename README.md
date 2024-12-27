# My Homelab Setup

I run a modest homelab to automate my home, host my own services, and store my own data.

## Hardware

- TP Link Archer WiFi 7 Router

- TP Link 8-Port Gigabit Switch (x2)

- TP Link 8-Port Gigabit PoE+ Switch

- Raspberry Pi 4

## Software

### Router

#### Block internet access for all IoT devices

I accomplished this by creating a Parental Controls profile for all IoT devices, and then turn off the 'Internet Access' toggle.

#### VPN

Setup a WireGuard server on the router with Home Network access only. Then configure clients with split-tunelling to only use Home Assistant with the VPN connection.
