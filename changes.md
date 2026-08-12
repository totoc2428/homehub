# Summary of Architectural Changes - OpenMediaVault HomeLab

**Date of Refactoring:** August 12, 2026  
**Target Environment:** Debian 13 (Trixie) amd64 | OpenMediaVault (OMV) 8.3.1-2  
**Host IP:** `192.168.1.64/24` | **Gateway:** `192.168.1.254` | **Pi-hole IP:** `192.168.1.53` (macvlan `lan_physique`)

---

## 1. Overview of Accomplishments

The HomeLab architecture has been refactored to be fully **"Plug & Play"**, secured with **Single Sign-On (Authentik SSO)** integrated via **Traefik ForwardAuth**, unified visually with a **Google/Immich-styled Homepage dashboard**, and automated with **Bash and Python cron scripts**.

### Key Infrastructure Improvements:
- **Centralized SSO**: Authentik handles identity for exposed services. ForwardAuth middleware redirects unauthenticated requests (e.g. `photos.lan`) to `auth.lan`.
- **Unified Modern Dashboard**: Homepage configured with custom CSS (`custom.css`) providing slate glassmorphic card design, rounded corners, subtle hover dynamics, and live widgets.
- **Preserved Hardware & Network Modes**: Home Assistant, Matter Server, and OpenThread maintain `network_mode: host` and strict USB device paths (`/dev/serial/by-path/pci-0000:00:1a.0-usb-0:1.1:1.0-port0` -> `/dev/ttyThread`).
- **Pi-hole DNS Integration**: Macvlan network configuration preserved with static IP `192.168.1.53`.
- **Automated Backup & Permissions**: Automated system archiving, photo rsync, and permission hardening (`root:Famille` with `750` mode mask).
- **Immich Library Automation**: REST API scripts for automated external library scanning and unassigned asset indexing into an "All Photos" album.

---

## 2. Inventory of Created Files & Stacks

### 2.1 Master & Modular Docker Stacks (`docker-compose.yml` & `stacks/`)

- [`docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/docker-compose.yml): Unified Docker Compose file aggregating all services, compatible with Dockge or standalone Docker Compose execution.
- [`stacks/01-traefik-sso/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/docker-compose.yml): Traefik v3 reverse proxy stack paired with Authentik SSO (PostgreSQL 16, Redis 7, Server, and Worker).
- [`stacks/01-traefik-sso/traefik/dynamic/middleware.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/traefik/dynamic/middleware.yml): Traefik dynamic file configuration defining the `authentik` ForwardAuth middleware.
- [`stacks/02-homepage/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/02-homepage/docker-compose.yml): Homepage dashboard container setup.
- [`stacks/02-homepage/config/settings.yaml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/02-homepage/config/settings.yaml): Layout and global settings for Homepage.
- [`stacks/02-homepage/config/services.yaml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/02-homepage/config/services.yaml): Defined service cards and live monitoring widgets (Immich, Home Assistant, Pi-hole, Traefik, Authentik).
- [`stacks/02-homepage/config/custom.css`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/02-homepage/config/custom.css): Custom CSS theme bringing Google / Immich minimalist dark glassmorphism styling.
- [`stacks/03-pihole/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/03-pihole/docker-compose.yml): Dedicated Pi-hole stack using macvlan driver on `enp4s0` (`192.168.1.53`).
- [`stacks/04-homeautomation/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/04-homeautomation/docker-compose.yml): Home Assistant, Matter Server, OpenThread (with `/dev/ttyThread` USB mapping), and Mosquitto MQTT.
- [`stacks/05-immich/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/05-immich/docker-compose.yml): Immich photo server, machine learning, Redis, and pgvecto-rs PostgreSQL, configured with Traefik labels for Authentik ForwardAuth protection (`photos.lan`).

### 2.2 Automation & Cron Scripts (`scripts/` & `crons/`)

- [`scripts/backup_system_photos.sh`](file:///c:/Users/charl/Documents/code/project/openmedia/scripts/backup_system_photos.sh):
  - **System Backup (05:00)**: Creates compressed tarball (`system_backup_YYYYMMDD_HHMMSS.tar.gz`) on backup disk (`/srv/dev-disk-by-uuid-7AF2DC71F2DC335D/backups/system/`). Retains last 7 days.
  - **Photos Sync (05:30)**: Incremental `rsync -av --delete` from photos disk (`/srv/dev-disk-by-uuid-52E654B8E6549E53/`) to backup disk (`/srv/dev-disk-by-uuid-7AF2DC71F2DC335D/backups/photos_sync/`).
  - **Permissions Hardening**: Executes `chown -R root:Famille` and `chmod -R 750` so standard family users only have read-only access.
- [`scripts/immich_scan_external.sh`](file:///c:/Users/charl/Documents/code/project/openmedia/scripts/immich_scan_external.sh): Bash script triggering forced scan of external read-only libraries via Immich REST API (`POST /api/libraries/{id}/scan`).
- [`scripts/immich_auto_album.py`](file:///c:/Users/charl/Documents/code/project/openmedia/scripts/immich_auto_album.py): Python 3 script using standard libraries (`urllib.request`) querying Immich REST API to discover assets not assigned to any album and inject them into an album named "All Photos".
- [`crons/homelab_crontab.snippet`](file:///c:/Users/charl/Documents/code/project/openmedia/crons/homelab_crontab.snippet): Host crontab configuration template.

---

## 3. Quick Start & Deployment Guide

### Step 1: Deploy Docker Stacks
To deploy all stacks using Docker Compose:
```bash
docker compose up -d
```
Or manage individual stacks in Dockge by adding the directories under `stacks/*`.

### Step 2: Install Automation Scripts on Debian Host
Copy the scripts to `/usr/local/bin` and grant execution privileges:
```bash
sudo cp scripts/backup_system_photos.sh /usr/local/bin/
sudo cp scripts/immich_scan_external.sh /usr/local/bin/
sudo cp scripts/immich_auto_album.py /usr/local/bin/

sudo chmod +x /usr/local/bin/backup_system_photos.sh
sudo chmod +x /usr/local/bin/immich_scan_external.sh
sudo chmod +x /usr/local/bin/immich_auto_album.py
```

### Step 3: Configure Host Crontab
Add the entries from `crons/homelab_crontab.snippet` into `/etc/crontab`:
```cron
00 05 * * * root /bin/bash /usr/local/bin/backup_system_photos.sh system >> /var/log/homelab_backup.log 2>&1
30 05 * * * root /bin/bash /usr/local/bin/backup_system_photos.sh photos >> /var/log/homelab_backup.log 2>&1
00 06 * * * root IMMICH_API_KEY="YOUR_API_KEY" /bin/bash /usr/local/bin/immich_scan_external.sh >> /var/log/immich_scan.log 2>&1
30 06 * * * root IMMICH_API_KEY="YOUR_API_KEY" /usr/bin/python3 /usr/local/bin/immich_auto_album.py >> /var/log/immich_album.log 2>&1
```
