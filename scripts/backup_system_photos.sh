#!/usr/bin/env bash
# ==============================================================================
# Script: backup_system_photos.sh
# Author: DevOps & Linux System Architect
# Description: Automated HomeLab System & Photo Disk Backup Script.
#              Generates a compressed system tar.gz archive (05:00) and performs
#              incremental photo rsync (05:30) to the ext4 backup drive.
#              Enforces root:Famille ownership with 750/640 permissions.
# Usage:
#   Root cron execution:
#   00 05 * * * root /usr/local/bin/backup_system_photos.sh system >> /var/log/homelab_backup.log 2>&1
#   30 05 * * * root /usr/local/bin/backup_system_photos.sh photos >> /var/log/homelab_backup.log 2>&1
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

# --- CONFIGURATION DEFAULT FALLBACKS ---
BACKUP_DISK_UUID="${BACKUP_DISK_UUID:-7AF2DC71F2DC335D}"
PHOTOS_DISK_UUID="${PHOTOS_DISK_UUID:-52E654B8E6549E53}"

BACKUP_MOUNT_POINT="${BACKUP_MOUNT_POINT:-/srv/dev-disk-by-uuid-${BACKUP_DISK_UUID}}"
PHOTOS_MOUNT_POINT="${PHOTOS_MOUNT_POINT:-/srv/dev-disk-by-uuid-${PHOTOS_DISK_UUID}}"

SYSTEM_BACKUP_DIR="${BACKUP_MOUNT_POINT}/backups/system"
PHOTOS_BACKUP_DIR="${BACKUP_MOUNT_POINT}/backups/photos_sync"

GROUP_NAME="${USER_FAMILY_GROUP:-Famille}"
RETENTION_DAYS=7

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MODE="${1:-all}" # Modes: 'system', 'photos', or 'all'

# --- LOGGING HELPERS ---
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

# --- ROOT PRIVILEGE CHECK ---
if [[ ${EUID} -ne 0 ]]; then
   log_error "This backup script must be executed with root privileges."
   exit 1
fi

# --- VERIFY BACKUP DISK MOUNT ---
if ! mountpoint -q "${BACKUP_MOUNT_POINT}"; then
    log_error "Backup disk is not mounted at ${BACKUP_MOUNT_POINT}. Aborting backup task."
    exit 1
fi

# --- FUNCTION: SYSTEM BACKUP (TAR.GZ ARCHIVE) ---
backup_system() {
    log "Starting system compressed archive backup..."
    mkdir -p "${SYSTEM_BACKUP_DIR}"

    ARCHIVE_FILE="${SYSTEM_BACKUP_DIR}/system_backup_${TIMESTAMP}.tar.gz"

    log "Archiving system files to ${ARCHIVE_FILE}..."
    tar --exclude="/proc" \
        --exclude="/sys" \
        --exclude="/dev" \
        --exclude="/pts" \
        --exclude="/run" \
        --exclude="/mnt" \
        --exclude="/media" \
        --exclude="/srv" \
        --exclude="/tmp" \
        --exclude="/lost+found" \
        --exclude="/var/lib/docker/overlay2" \
        -czf "${ARCHIVE_FILE}" / || {
            log "Tar archive finished with warnings or minor exclusions."
        }

    log "System backup archive completed: ${ARCHIVE_FILE}"

    # Purge backups older than RETENTION_DAYS
    log "Cleaning system backups older than ${RETENTION_DAYS} days..."
    find "${SYSTEM_BACKUP_DIR}" -type f -name "system_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete
}

# --- FUNCTION: PHOTOS INCREMENTAL RSYNC ---
backup_photos() {
    if ! mountpoint -q "${PHOTOS_MOUNT_POINT}"; then
        log_error "Photos disk is not mounted at ${PHOTOS_MOUNT_POINT}. Aborting photo sync."
        exit 1
    fi

    log "Starting incremental photo synchronization (rsync)..."
    mkdir -p "${PHOTOS_BACKUP_DIR}"

    rsync -av --delete \
        --prune-empty-dirs \
        "${PHOTOS_MOUNT_POINT}/" \
        "${PHOTOS_BACKUP_DIR}/"

    log "Photo synchronization completed successfully."
}

# --- FUNCTION: ENFORCE STRICT FAMILY READ-ONLY PERMISSIONS ---
apply_permissions() {
    log "Enforcing security permissions (chown root:${GROUP_NAME}, chmod 750/640) on backup mount point..."
    
    # Check if target group exists on system
    if getent group "${GROUP_NAME}" >/dev/null 2>&1; then
        chown -R root:"${GROUP_NAME}" "${BACKUP_MOUNT_POINT}"
    else
        log_error "Group '${GROUP_NAME}' does not exist on host. Defaulting ownership to root:root."
        chown -R root:root "${BACKUP_MOUNT_POINT}"
    fi

    # Directories receive 750 (drwxr-x---), Files receive 640 (-rw-r-----)
    find "${BACKUP_MOUNT_POINT}" -type d -exec chmod 750 {} +
    find "${BACKUP_MOUNT_POINT}" -type f -exec chmod 640 {} +

    log "Permissions successfully enforced. Family members in group '${GROUP_NAME}' have read-only access."
}

# --- MAIN DISPATCH ---
case "${MODE}" in
    system)
        backup_system
        apply_permissions
        ;;
    photos)
        backup_photos
        apply_permissions
        ;;
    all)
        backup_system
        backup_photos
        apply_permissions
        ;;
    *)
        log_error "Unknown mode '${MODE}'. Usage: $0 {system|photos|all}"
        exit 1
        ;;
esac

log "Backup task finished successfully."
