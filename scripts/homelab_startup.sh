#!/usr/bin/env bash
# ==============================================================================
# Script: homelab_startup.sh
# Author: DevOps & Linux System Architect
# Description: Plug & Play automated startup script for HomeLab Docker Stacks.
#              Ensures Docker is ready, creates required networks, loads .env,
#              and brings up all containers on system boot.
# Location: scripts/homelab_startup.sh
# ==============================================================================

set -euo pipefail

# --- CONFIGURATION & PATHS ---
STACKS_DIR="${STACKS_DIR:-/opt/openmedia/stacks}"
FALLBACK_STACKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../stacks" && pwd)"

if [[ -d "${STACKS_DIR}" ]]; then
    TARGET_DIR="${STACKS_DIR}"
elif [[ -d "${FALLBACK_STACKS_DIR}" ]]; then
    TARGET_DIR="${FALLBACK_STACKS_DIR}"
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Stacks directory not found." >&2
    exit 1
fi

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

log "=== Initializing HomeLab Plug & Play Boot Service ==="

# 1. WAIT FOR DOCKER DAEMON
MAX_RETRIES=30
RETRY_COUNT=0

log "Verifying Docker daemon availability..."
until docker info >/dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [[ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]]; then
        log_error "Docker daemon failed to respond within $((MAX_RETRIES * 2)) seconds."
        exit 1
    fi
    log "Waiting for Docker daemon to initialize... (${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 2
done
log "Docker daemon is active and responsive."

# 2. ENSURE PROXY NETWORK EXISTS
log "Ensuring external Docker network 'proxy' exists..."
if ! docker network inspect proxy >/dev/null 2>&1; then
    docker network create proxy || {
        log_error "Failed to create Docker network 'proxy'."
        exit 1
    }
    log "Created external Docker network 'proxy'."
else
    log "Docker network 'proxy' already exists."
fi

# 3. NAVIGATE TO STACKS DIRECTORY AND LOAD ENV
log "Navigating to stacks directory: ${TARGET_DIR}"
cd "${TARGET_DIR}"

ENV_FILE="${TARGET_DIR}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    log "Loading environment variables from ${ENV_FILE}..."
    set -o allexport
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +o allexport
else
    log_error "Warning: No .env file found at ${ENV_FILE}. Using container defaults."
fi

# 4. SPIN UP STACKS
log "Spinning up HomeLab container stacks (docker compose up -d)..."
docker compose --env-file "${ENV_FILE}" up -d || {
    log_error "Docker compose up -d encountered errors during execution."
    exit 1
}

log "=== HomeLab Stacks Successfully Initialized and Running ==="
