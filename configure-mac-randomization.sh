#!/bin/bash
# Script to enable global MAC address randomization for Wi-Fi in Pop!_OS / NetworkManager

CONF_FILE="/etc/NetworkManager/conf.d/30-mac-randomization.conf"

echo "=========================================="
echo "Configuring Global Wi-Fi MAC Randomization"
echo "=========================================="

# Create the configuration content
# We configure:
# 1. wifi.scan-rand-mac-address=yes (randomizes MAC while scanning for networks)
# 2. wifi.cloned-mac-address=random (generates a brand-new random MAC address on every connection)
# 3. ethernet.cloned-mac-address=random (optional but included for ethernet privacy)
TEMP_CONF=$(mktemp)
cat << 'EOF' > "$TEMP_CONF"
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

echo "Writing configuration to $CONF_FILE..."
sudo mkdir -p "$(dirname "$CONF_FILE")"
sudo cp "$TEMP_CONF" "$CONF_FILE"
rm "$TEMP_CONF"

# Make sure permissions are correct (readable by everyone, writable only by root/owner)
sudo chmod 644 "$CONF_FILE"

echo "Restarting NetworkManager to apply changes..."
sudo systemctl restart NetworkManager

echo "=========================================="
echo "MAC Randomization is now configured and active!"
echo "Your MAC address will be randomized:"
echo " 1. During background Wi-Fi scanning."
echo " 2. Whenever you connect to any Wi-Fi or Ethernet network."
echo "=========================================="
