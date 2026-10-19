#!/usr/bin/env bash

# Exit immediately if a command fails
set -e

echo "=== 1. System update and Docker installation ==="
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker --now

echo "=== 2. Repository cloning ==="
if [ ! -d "WiFiChallengeLab-docker" ]; then
    git clone https://github.com/r4ulcl/WiFiChallengeLab-docker
fi
cd WiFiChallengeLab-docker

echo "=== 3. Loading mac80211_hwsim module ==="
# Remove the module if already loaded to avoid errors, then reload it
sudo modprobe -r mac80211_hwsim 2>/dev/null || true
sudo modprobe mac80211_hwsim radios=64

echo "=== 4. Module persistence on reboot ==="
if ! grep -q "mac80211_hwsim" /etc/modules-load.d/modules.conf 2>/dev/null; then
    echo "mac80211_hwsim" | sudo tee -a /etc/modules-load.d/modules.conf
fi
echo "options mac80211_hwsim radios=64" | sudo tee /etc/modprobe.d/mac80211_hwsim.conf

echo "=== 5. Applying fix for wlan_config ==="
# Check if the fix has already been applied to avoid duplicating it
if ! grep -q "wlan_config:/root/wlan_config" docker-compose.yml; then
    sed -i '/container_name: WiFiChallengeLab-APs/,/volumes:/{/volumes:/a\      - ./wlan_config:/root/wlan_config:ro
    }' docker-compose.yml

    sed -i '/container_name: WiFiChallengeLab-Clients/,/volumes:/{/volumes:/a\      - ./wlan_config:/root/wlan_config:ro
    }' docker-compose.yml
else
    echo "wlan_config mount is already present in docker-compose.yml. Skipping."
fi

echo "=== 6. Verifying the fix (2 lines should appear) ==="
grep -n "wlan_config:/root/wlan_config" docker-compose.yml

echo "=== 7. Starting containers ==="
sudo docker compose --file docker-compose.yml up -d

echo "=== 8. Final verification ==="
echo "Number of virtual wireless interfaces:"
iw dev | grep Interface | wc -l
echo "Container status:"
sudo docker ps
echo "--- Log APs ---"
sudo docker logs WiFiChallengeLab-APs --tail 30
echo "--- Log Clients ---"
sudo docker logs WiFiChallengeLab-Clients --tail 30

echo "Setup completed!"
