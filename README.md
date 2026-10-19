# WiFiChallengeLab Bootstrap

Automated, opinionated setup for [WiFiChallengeLab-docker](https://github.com/r4ulcl/WiFiChallengeLab-docker), primarily targeting **Kali Linux** (and Debian-based distros in general).

This is **not a fork** of the upstream project. It's a bootstrap guide + fix to get a working Wi-Fi lab on a fresh VM with `mac80211_hwsim`, working around a few known upstream issues:

- `docker-compose-challenge.yml` is broken/deprecated upstream.
- The `wlan_config` file is not mounted into the `APs` and `Clients` containers, so `cronClients.sh` fails silently.
- `mac80211_hwsim` is not persisted across reboots.

---

## What it does

- Installs Docker + docker-compose.
- Loads `mac80211_hwsim` with 64 virtual radios (16 clients + APs, with headroom).
- Persists the module and its parameters across VM reboots.
- **Patches the upstream `docker-compose.yml`** by adding `./wlan_config:/root/wlan_config:ro` to the `WiFiChallengeLab-APs` and `WiFiChallengeLab-Clients` services.  
  Required because `cronClients.sh` inside the containers expects `wlan_config` and fails silently without it.
- Starts the containers and prints a verification summary (interfaces, containers, logs).

> ⚠️ **Do not use `docker-compose-challenge.yml`**: it's broken/deprecated upstream. This setup uses the base `docker-compose.yml`.

---

## Requirements

- **Kali Linux** (tested target) or any Debian-based distro (Ubuntu 22.04+, Debian 12+).
- Intended for **VMs / isolated environments** — `mac80211_hwsim` is a simulator and does not touch real Wi-Fi hardware.
- `sudo` access (Kali often runs as `root` by default; the guide keeps `sudo` for portability).
- ~4 GB RAM and ~10 GB free disk.
- Internet access (for `git clone` and Docker image pulls).

---

## Quick start

```bash
git clone https://github.com/enricomarogna/wifichallengelab-bootstrap
cd wifichallengelab-bootstrap
chmod +x setup.sh
sudo ./setup.sh
```

If you prefer to run the steps manually, follow **Manual setup** below.

---

## Manual setup

### 1. Update system and install Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker --now
```

> On Kali, `docker.io` and `docker-compose` are available in the default repos.  
> If you prefer Docker's official packages, install `docker-ce` / `docker-compose-plugin` from Docker's apt repo instead — the rest of this guide is unchanged.

### 2. Clone the upstream repo

```bash
git clone https://github.com/r4ulcl/WiFiChallengeLab-docker
cd WiFiChallengeLab-docker
```

> Use the base `docker-compose.yml`. **NOT** `docker-compose-challenge.yml`.

### 3. Load `mac80211_hwsim`

```bash
sudo modprobe mac80211_hwsim radios=64
```

### 4. Persist the module across reboots

```bash
echo "mac80211_hwsim" | sudo tee -a /etc/modules-load.d/modules.conf
echo "options mac80211_hwsim radios=64" | sudo tee /etc/modprobe.d/mac80211_hwsim.conf
```

### 5. Patch `docker-compose.yml` (mount `wlan_config`)

```bash
sed -i '/container_name: WiFiChallengeLab-APs/,/volumes:/{/volumes:/a\      - ./wlan_config:/root/wlan_config:ro
}' docker-compose.yml

sed -i '/container_name: WiFiChallengeLab-Clients/,/volumes:/{/volumes:/a\      - ./wlan_config:/root/wlan_config:ro
}' docker-compose.yml
```

### 6. Verify the patch (must print **2 lines**)

```bash
grep -n "wlan_config:/root/wlan_config" docker-compose.yml
```

### 7. Start the containers

```bash
sudo docker compose --file docker-compose.yml up -d
```

### 8. Final checks

```bash
iw dev | grep Interface | wc -l          # expected: ~64
sudo docker ps
sudo docker logs WiFiChallengeLab-APs --tail 30
sudo docker logs WiFiChallengeLab-Clients --tail 30
```

---

## Quick checklist

- [ ] `iw dev | grep Interface | wc -l` returns a number > 0 (ideally ~64).
- [ ] `sudo docker ps` shows `WiFiChallengeLab-APs` and `WiFiChallengeLab-Clients` as `Up`.
- [ ] `sudo docker logs WiFiChallengeLab-APs` shows no `wlan_config` missing errors.
- [ ] `grep -c "wlan_config:/root/wlan_config" docker-compose.yml` returns `2`.

If any of these fail, see **Troubleshooting**.

---

## Troubleshooting

**`cronClients.sh: wlan_config: No such file or directory` in the logs**  
The patch in step 5 was not applied. Re-run it and check with `grep`.

**`docker compose up` complains about the compose file**  
Make sure you're pointing at `docker-compose.yml` (base), not `docker-compose-challenge.yml`.

**No `wlan*` interfaces after reboot**  
Check that `/etc/modules-load.d/modules.conf` contains `mac80211_hwsim` and `/etc/modprobe.d/mac80211_hwsim.conf` contains `options mac80211_hwsim radios=64`. If you edited those files after the first boot, run `sudo modprobe -r mac80211_hwsim && sudo modprobe mac80211_hwsim radios=64` (or reboot).

**Fewer radios than expected after `modprobe`**  
The module may already be loaded with an old value. Unload it first: `sudo modprobe -r mac80211_hwsim`, then re-load with `radios=64`.

**Containers are up but no APs/clients visible**  
Check `sudo docker logs WiFiChallengeLab-APs --tail 100` and confirm `wlan_config` exists in the root of the upstream repo.

**Kali-specific notes**  
- Kali runs as `root` by default, so `sudo` is optional but harmless.  
- If your Kali image ships without `iw`, install it: `sudo apt install -y iw`.  
- Docker service name may vary slightly between Kali releases; `sudo systemctl enable docker --now` is the standard path.

---

## Notes

- Designed for **VMs / isolated environments**. `mac80211_hwsim` is a simulator — it never touches real Wi-Fi hardware.
- 64 radios is a safety margin; lower `radios=` if you have resource constraints.
- This repo is a wrapper. Functional bugs in the lab itself should be reported **upstream** to [r4ulcl/WiFiChallengeLab-docker](https://github.com/r4ulcl/WiFiChallengeLab-docker).

---

## Credits

- Original lab: [r4ulcl/WiFiChallengeLab-docker](https://github.com/r4ulcl/WiFiChallengeLab-docker).
- This repo: only a bootstrap script / setup guide + fixes. No lab code is modified beyond the extra `wlan_config` mount injected via `sed`.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
