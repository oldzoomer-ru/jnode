#!/bin/bash
# ============================================================
# jNode Docker Backup Script
# Backs up all persistent volumes and configuration
# Usage: ./scripts/backup.sh [backup_dir]
# ============================================================

set -euo pipefail

# Configuration
BACKUP_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="jnode-backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
COMPRESSION="gz"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi

    if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
        error "Docker Compose is not installed"
        exit 1
    fi

    if ! docker ps --format '{{.Names}}' | grep -q '^jnode$'; then
        warn "jnode container is not running"
        warn "Backup will use volume snapshots only"
    fi
}

# Create backup directory
create_backup_dir() {
    mkdir -p "${BACKUP_PATH}"
    log "Backup directory: ${BACKUP_PATH}"
}

# Backup configuration files
backup_config() {
    log "Backing up configuration files..."
    local CONFIG_SRC="./docs/configs"

    if [ -d "${CONFIG_SRC}" ]; then
        cp -r "${CONFIG_SRC}" "${BACKUP_PATH}/configs"
        success "Configuration files backed up"
    else
        warn "Configuration directory not found: ${CONFIG_SRC}"
    fi
}

# Backup volumes using container
backup_volumes_with_container() {
    log "Backing up volumes from running container..."

    local VOLUMES=("jnode-db" "jnode-log" "jnode-inbound" "jnode-nodelist" "jnode-tmp" "jnode-files" "jnode-troubleshooting")

    for vol in "${VOLUMES[@]}"; do
        local vol_dir="${BACKUP_PATH}/volumes/${vol}"
        mkdir -p "${vol_dir}"

        if docker volume inspect "${vol}" &> /dev/null; then
            docker run --rm \
                -v "${vol}:/source:ro" \
                -v "${vol_dir}:/dest" \
                alpine tar czf "/dest/${vol}.tar.gz" -C /source . 2>/dev/null || {
                    warn "Failed to backup volume: ${vol}"
                    continue
                }
            success "Volume backed up: ${vol}"
        else
            warn "Volume not found: ${vol}"
        fi
    done
}

# Backup database directly from container
backup_database() {
    log "Backing up database..."

    if docker ps --format '{{.Names}}' | grep -q '^jnode$'; then
        local DB_PATH="/app/jnode/db"

        # Backup H2 database files
        docker run --rm \
            --network host \
            -v "jnode-db:/db" \
            alpine tar czf "${BACKUP_PATH}/jnode-db.tar.gz" -C /db . 2>/dev/null || {
            warn "Failed to backup H2 database"
        }

        # If using PostgreSQL
        if docker ps --format '{{.Names}}' | grep -q '^jnode-postgres$'; then
            log "Backing up PostgreSQL database..."
            docker run --rm \
                --network host \
                -v "${BACKUP_PATH}:/backup" \
                postgres:18-alpine \
                sh -c "pg_dump -U jnode jnode | gzip > /backup/jnode-postgres.sql.gz" 2>/dev/null || {
                    warn "Failed to backup PostgreSQL database"
                }
        fi

        # If using MySQL
        if docker ps --format '{{.Names}}' | grep -q '^jnode-mysql$'; then
            log "Backing up MySQL database..."
            docker run --rm \
                --network host \
                -v "${BACKUP_PATH}:/backup" \
                mysql:9.1 \
                sh -c "mysqldump -u jnode -p${MYSQL_PASSWORD:-jnode} jnode | gzip > /backup/jnode-mysql.sql.gz" 2>/dev/null || {
                    warn "Failed to backup MySQL database"
                }
        fi

        success "Database backup completed"
    else
        warn "No running jnode container found, skipping database backup"
    fi
}

# Create backup manifest
create_manifest() {
    log "Creating backup manifest..."

    cat > "${BACKUP_PATH}/MANIFEST.txt" << EOF
jNode Backup Manifest
=====================
Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname)
Backup Type: Full
Compression: ${COMPRESSION}

Volumes:
  - jnode-db
  - jnode-log
  - jnode-inbound
  - jnode-nodelist
  - jnode-tmp
  - jnode-files
  - jnode-troubleshooting

Configuration: ./docs/configs/

Restore Instructions:
  1. Stop jnode: docker compose down
  2. Extract: tar xzf ${BACKUP_NAME}.tar.gz -C /
  3. Restore volumes: docker run --rm -v jnode-db:/dest -v \${BACKUP_PATH}/volumes/jnode-db:/source alpine tar xzf /source/jnode-db.tar.gz -C /dest
  4. Start jnode: docker compose up -d
EOF

    success "Manifest created"
}

# Create compressed archive
create_archive() {
    log "Creating compressed archive..."

    local archive_name="${BACKUP_DIR}/${BACKUP_NAME}.tar.${COMPRESSION}"

    tar czf "${archive_name}" -C "${BACKUP_DIR}" "${BACKUP_NAME}" 2>/dev/null || {
        error "Failed to create archive"
        return 1
    }

    local archive_size=$(du -h "${archive_name}" | cut -f1)
    success "Archive created: ${archive_name} (${archive_size})"

    # Keep original directory for verification
    echo "${archive_name}"
}

# Cleanup temporary files
cleanup() {
    if [ "${KEEP_TEMP:-false}" = "true" ]; then
        log "Keeping temporary files in ${BACKUP_PATH}"
        return
    fi

    log "Cleaning up temporary files..."
    rm -rf "${BACKUP_PATH}"
    success "Temporary files cleaned up"
}

# Main execution
main() {
    log "========================================="
    log "  jNode Docker Backup"
    log "========================================="

    check_prerequisites
    create_backup_dir
    backup_config
    backup_volumes_with_container
    backup_database
    create_manifest

    local archive_path
    archive_path=$(create_archive)

    cleanup

    log "========================================="
    success "Backup completed successfully!"
    log "Archive: ${archive_path}"
    log "========================================="

    # List backup contents
    log "Backup contents:"
    tar tzf "${archive_path}" | head -20
    if [ "$(tar tzf "${archive_path}" | wc -l)" -gt 20 ]; then
        log "... and more"
    fi
}

# Run main
main "$@"
