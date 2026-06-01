# Global Wi-Fi MAC Address Randomization

This directory contains the script to configure global, persistent MAC address randomization on Pop!_OS (and other Debian/Ubuntu-based systems using NetworkManager).

## Files
* `configure-mac-randomization.sh`: The configuration and activation script.

## Setup Instructions

To configure global MAC address randomization:

1. Open your terminal.
2. Run the script using the following commands:
   ```bash
   chmod +x configure-mac-randomization.sh
   sudo ./configure-mac-randomization.sh
   ```
3. Enter your administrative (`sudo`) password when prompted.

## What This Does
The script creates a global configuration file at `/etc/NetworkManager/conf.d/30-mac-randomization.conf` with the following settings:
* **Scanning Randomization**: Randomizes your MAC address while your Wi-Fi device is scanning for networks (before connecting), preventing tracking by nearby access points.
* **Connection Randomization**: Generates a brand-new random MAC address every single time you connect or reconnect to any Wi-Fi or Ethernet network.

This configuration is permanent and persists across computer restarts.
