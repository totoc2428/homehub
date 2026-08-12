#!/usr/bin/env bash
# ==============================================================================
# Script: immich_scan_external.sh
# Author: DevOps & Linux System Architect
# Description: Triggers a forced scan of Immich External Photo Libraries
#              using the REST API. Automatically loads settings from .env.
# Usage:
#   /usr/local/bin/immich_scan_external.sh
# ==============================================================================

set -euo pipefail

# --- LOAD CENTRALIZED ENVIRONMENT VARIABLES ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../stacks/.env"

if [[ -f "${ENV_FILE}" ]]; then
    set -o allexport
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +o allexport
fi

# --- CONFIGURATION & ENVIRONMENT ---
IMMICH_URL="${IMMICH_URL:-http://127.0.0.1:2283}"
IMMICH_API_KEY="${IMMICH_API_KEY:-}"
LIBRARY_ID="${LIBRARY_ID:-}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

if [[ -z "${IMMICH_API_KEY}" ]]; then
    log_error "IMMICH_API_KEY environment variable is missing or empty."
    exit 1
fi

# --- DISCOVER EXTERNAL LIBRARY ID IF NOT SPECIFIED ---
if [[ -z "${LIBRARY_ID}" ]]; then
    log "Querying Immich API for External Libraries at ${IMMICH_URL}..."

    RESPONSE=$(curl -s -f -X GET "${IMMICH_URL}/api/libraries" \
        -H "Accept: application/json" \
        -H "x-api-key: ${IMMICH_API_KEY}") || {
            log_error "Failed to connect to Immich API at ${IMMICH_URL}."
            exit 1
        }

    # Extract first library ID of type 'EXTERNAL' using Python parsing
    LIBRARY_ID=$(python3 -c "
import sys, json
try:
    libs = json.loads(sys.argv[1])
    for lib in libs:
        if lib.get('type') == 'EXTERNAL':
            print(lib.get('id'))
            break
except Exception:
    sys.exit(1)
" "${RESPONSE}")

    if [[ -z "${LIBRARY_ID}" ]]; then
        log_error "No external library found in Immich instance."
        exit 1
    fi
    log "Discovered External Library ID: ${LIBRARY_ID}"
fi

# --- TRIGGER FORCED SCAN VIA REST API ---
log "Triggering forced scan for External Library ID: ${LIBRARY_ID}..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${IMMICH_URL}/api/libraries/${LIBRARY_ID}/scan" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "x-api-key: ${IMMICH_API_KEY}" \
    -d '{"reason": "scheduled_cron_scan"}')

if [[ "${HTTP_STATUS}" -eq 200 || "${HTTP_STATUS}" -eq 201 ]]; then
    log "Successfully triggered scan for library ${LIBRARY_ID} (HTTP ${HTTP_STATUS})."
else
    log_error "Failed to trigger scan for library ${LIBRARY_ID}. HTTP Status Code: ${HTTP_STATUS}"
    exit 1
fi
