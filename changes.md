# Summary of Architectural Changes - OpenMediaVault HomeLab

**Date of Refactoring:** August 12, 2026  
**Target Environment:** Debian 13 (Trixie) amd64 | OpenMediaVault (OMV) 8.3.1-2  
**Host IP:** `192.168.1.64/24` | **Gateway:** `192.168.1.254` | **Pi-hole IP:** `192.168.1.53` (macvlan `lan_physique`)

---

## 1. Overview of Accomplishments

The HomeLab architecture has been refactored to be fully **"Plug & Play"**, secured with **Authelia Single Sign-On (SSO)** integrated via **Traefik ForwardAuth**, unified visually with a **Google/Immich App Launcher Dashboard**, and styled consistently across services (Pi-hole, Home Assistant).

### Key Infrastructure & UI/UX Improvements:
- **Lightweight File-Backed SSO**: Authelia configured with file database (`users_database.yml`) managing family accounts (`charles.coude`, `annouk.coude`, `anne.coude`, `agathe.coude`, `hermine.coude`, `dominique.coude`).
- **Role-Based Access Control**:
  - `Family` group: Access to Homepage (`home.lan`) and Immich (`photos.lan`).
  - `admin` group (`charles.coude`, `dominique.coude`): Strict restricted access to administrative portals (Traefik Dashboard `traefik.lan`, OpenMediaVault `data.lan`).
- **Unified Modern Dashboard**: Homepage styled as a Google App Launcher with Material Design 3 / Immich glassmorphic cards (`custom.css`), rounded corners (20px), subtle neon glow effects, and live widgets.
- **UI Theme Harmonization**:
  - **Pi-hole**: Dark material theme injected via volume mount (`custom-theme.css`).
  - **Home Assistant**: Google Theme / Material 3 YAML instructions provided for HACS.
- **Strict Persistence & Zero Data Loss**: Every service uses explicit bind mounts (`./authelia/config:/config`, `./stacks/02-homepage/config:/app/config`).

---

## 2. Inventory of Created Files & Stacks

### 2.1 Master & Modular Docker Stacks (`docker-compose.yml` & `stacks/`)

- [`docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/docker-compose.yml): Unified Docker Compose file aggregating all services with Authelia SSO and Homepage.
- [`stacks/01-traefik-sso/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/docker-compose.yml): Traefik v3 reverse proxy paired with Authelia SSO.
- [`stacks/01-traefik-sso/authelia/configuration.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/authelia/configuration.yml): Main Authelia config specifying SQLite storage, argon2id password hashing, and domain rules.
- [`stacks/01-traefik-sso/authelia/users_database.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/authelia/users_database.yml): Local user database with Argon2id password hashes for family and admin accounts.
- [`stacks/01-traefik-sso/traefik/dynamic/middleware.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/traefik/dynamic/middleware.yml): Traefik dynamic file configuration defining the `authelia` ForwardAuth middleware (`http://authelia:9091/api/verify?rd=http://auth.lan/`).
- [`stacks/02-homepage/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/02-homepage/docker-compose.yml): Homepage dashboard container setup.
- [`stacks/02-homepage/config/settings.yaml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/02-homepage/config/settings.yaml): Global layout settings for Homepage.
- [`stacks/02-homepage/config/services.yaml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/02-homepage/config/services.yaml): Google App Launcher service cards and live widgets (Immich, HA, Pi-hole, Traefik, Authelia, OMV).
- [`stacks/02-homepage/config/custom.css`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/02-homepage/config/custom.css): Google / Immich Material glassmorphism styling file.
- [`stacks/03-pihole/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/03-pihole/docker-compose.yml): Pi-hole stack with custom theme volume injection.
- [`stacks/03-pihole/pihole/custom-theme.css`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/03-pihole/pihole/custom-theme.css): Pi-hole dark material theme.
- [`stacks/04-homeautomation/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/04-homeautomation/docker-compose.yml): Home Assistant, Matter Server, OpenThread, and Mosquitto MQTT.
- [`stacks/05-immich/docker-compose.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/05-immich/docker-compose.yml): Immich photo server stack protected by Authelia ForwardAuth labels.

---

## 3. Deployment & Quick Start Guide

```bash
# 1. Environment file setup
cp .env.exemple .env
cp .env.exemple stacks/.env

# 2. Spin up containers
docker compose up -d

# 3. Enable host boot service
sudo cp scripts/homelab-stacks.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-stacks.service
```
