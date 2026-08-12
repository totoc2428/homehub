# Summary of Architectural Changes - OpenMediaVault HomeLab

**Date of Refactoring:** August 12, 2026  
**Target Environment:** Debian 13 (Trixie) amd64 | OpenMediaVault (OMV) 8.3.1-2  
**Host IP:** `192.168.1.64/24` | **Gateway:** `192.168.1.254` | **Pi-hole IP:** `192.168.1.53` (macvlan `lan_physique`)

---

## 1. Overview of Accomplishments

The HomeLab architecture has been upgraded with **Automated User Onboarding & 4-Tier Access Control**. Hardcoded accounts in static configuration files have been completely eliminated and replaced by a central user source registry (`users.yaml`), an `admin_service` system account, and an automated Python initialization script (`generate_authelia_users.py`).

### Key Infrastructure & Security Improvements:
- **Central User Registry (`users.yaml`)**: Serves as the single source of truth for user accounts (`username`, `displayname`, `email`, `phone`, `role`).
- **Internal Service Account (`admin_service`)**: System account with strong random password auto-generated during initial boot, saved to `.env` (`ADMIN_SERVICE_PASSWORD`) for cron jobs, API scripts, and backup automation.
- **Dynamic SSO Initialization (`scripts/generate_authelia_users.py`)**: Python script running on host boot before Authelia starts, generating Argon2id password hashes, preserving credentials idempotently (`users_credentials.json`), and dynamically compiling `users_database.yml`.
- **4-Tier Access Control Policy**:
  - `administrator`: Full access to all applications and administrative portals (`data.lan`, `traefik.lan`, `portainer.lan`). Assigned to `charles.coude`, `dominique.coude`, and `admin_service`.
  - `manager`: Access to standard applications and management configuration endpoints (`annouk.coude`).
  - `standard`: Basic user access to family applications (`home.lan`, `photos.lan`, Home Assistant). Assigned to `anne.coude`, `agathe.coude`, `hermine.coude`.
  - `guest`: Restricted read-only access for guest users (`guest_user`).

---

## 2. Inventory of Created Files & Automation Scripts

### 2.1 User Registry & SSO Automation

- [`users.yaml`](file:///c:/Users/charl/Documents/code/project/openmedia/users.yaml) & [`stacks/users.yaml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/users.yaml): Central user source database.
- [`scripts/generate_authelia_users.py`](file:///c:/Users/charl/Documents/code/project/openmedia/scripts/generate_authelia_users.py): Idempotent Python initializer script compiling `users_database.yml` and managing `admin_service` credentials.
- [`stacks/01-traefik-sso/authelia/users_credentials.json`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/authelia/users_credentials.json): Secure persistent store for generated temporary user credentials.
- [`stacks/01-traefik-sso/authelia/users_database.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/authelia/users_database.yml): Dynamically compiled Authelia user database.
- [`stacks/01-traefik-sso/authelia/configuration.yml`](file:///c:/Users/charl/Documents/code/project/openmedia/stacks/01-traefik-sso/authelia/configuration.yml): Updated 4-tier domain access control policy rules.
- [`scripts/homelab_startup.sh`](file:///c:/Users/charl/Documents/code/project/openmedia/scripts/homelab_startup.sh): Host boot script invoking `generate_authelia_users.py` prior to `docker compose up -d`.

---

## 3. Quick Start & Deployment

```bash
# 1. Add/modify users in users.yaml
nano users.yaml

# 2. Run the dynamic user generator
py scripts/generate_authelia_users.py

# 3. Spin up the HomeLab stack
docker compose up -d
```
