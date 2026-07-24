#!/usr/bin/env bash
# backup.sh — test-python-project 数据备份脚本
# 备份: PostgreSQL 数据 + Docker volumes
set -euo pipefail

PROJECT_NAME="test-python-project"
BACKUP_DIR="backups"
DOCKER_HOST="unix:///Users/huoke/.colima/docker.sock"
DB_CONTAINER="hawk-postgres"
DB_USER="{{DB_USER}}"
RETENTION_DAYS=7

export DOCKER_HOST

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
mkdir -p "$BACKUP_DIR"

log_info()  { echo "[INFO]  $(date '+%H:%M:%S') $*"; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*"; }

# ============================================================
# PostgreSQL 备份
# ============================================================
backup_postgres() {
    log_info "Backing up PostgreSQL..."

    if ! docker ps --format '{{.Names}}' | grep -q "$DB_CONTAINER"; then
        log_info "PostgreSQL container not found, skipping"
        return
    fi

    local dump_file="$BACKUP_DIR/pg_backup_${TIMESTAMP}.sql"

    docker exec "$DB_CONTAINER" pg_dumpall -U "$DB_USER" > "$dump_file"

    if [ -s "$dump_file" ]; then
        local size
        size=$(du -h "$dump_file" | cut -f1)
        log_info "PostgreSQL backup saved: $dump_file ($size)"
    else
        log_error "PostgreSQL backup is empty!"
        rm -f "$dump_file"
        return 1
    fi
}

# ============================================================
# Volume 备份
# ============================================================
backup_volumes() {
    log_info "Backing up Docker volumes..."

    local volume_name="${PROJECT_NAME}-data"

    if ! docker volume inspect "$volume_name" > /dev/null 2>&1; then
        log_info "Volume $volume_name not found, skipping"
        return
    fi

    local archive="$BACKUP_DIR/volume_${PROJECT_NAME}_${TIMESTAMP}.tar.gz"

    docker run --rm \
        -v "$volume_name":/source:ro \
        -v "$(pwd)/$BACKUP_DIR":/backup \
        alpine tar czf "/backup/volume_${PROJECT_NAME}_${TIMESTAMP}.tar.gz" -C /source .

    if [ -f "$archive" ]; then
        local size
        size=$(du -h "$archive" | cut -f1)
        log_info "Volume backup saved: $archive ($size)"
    else
        log_error "Volume backup failed!"
        return 1
    fi
}

# ============================================================
# 清理旧备份
# ============================================================
cleanup_old_backups() {
    log_info "Cleaning backups older than $RETENTION_DAYS days..."

    local count
    count=$(find "$BACKUP_DIR" -name "*.sql" -mtime +$RETENTION_DAYS -type f 2>/dev/null | wc -l | tr -d ' ')
    count=$((count + $(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -type f 2>/dev/null | wc -l | tr -d ' ')))

    find "$BACKUP_DIR" -name "*.sql" -mtime +$RETENTION_DAYS -type f -delete 2>/dev/null
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -type f -delete 2>/dev/null

    log_info "Cleaned up $count old backup(s)"
}

# ============================================================
# 主流程
# ============================================================
main() {
    log_info "=== Starting backup for $PROJECT_NAME ==="

    backup_postgres
    backup_volumes
    cleanup_old_backups

    log_info "=== Backup complete ✓ ==="
    log_info "Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
}

main "$@"
