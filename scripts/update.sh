#!/bin/bash

# Portfolio Update Script
# This script updates the portfolio from an older version to a newer version

set -e

# Configuration
PROJECT_NAME="portfolio"
DEPLOY_DIR="/var/www/portfolio"
BACKUP_DIR="/var/backups/portfolio"
LOG_FILE="/var/log/portfolio-update.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Get current version
get_current_version() {
    if [ -f "$DEPLOY_DIR/package.json" ]; then
        grep '"version"' "$DEPLOY_DIR/package.json" | cut -d'"' -f4
    else
        echo "unknown"
    fi
}

# Compare versions
version_greater() {
    local current="$1"
    local new="$2"

    if [ "$current" = "unknown" ]; then
        return 0
    fi

    # Simple version comparison
    printf '%s\n%s\n' "$current" "$new" | sort -V -C
    return $?
}

# Update application
update_application() {
    local from_version="$1"
    local to_version="$2"

    log "Updating portfolio from version $from_version to $to_version"

    # Create backup before update
    BACKUP_NAME="portfolio-update-backup-$(date +%Y%m%d-%H%M%S)"
    cp -r "$DEPLOY_DIR" "$BACKUP_DIR/$BACKUP_NAME"
    log "Backup created: $BACKUP_DIR/$BACKUP_NAME"

    # Download new version
    cd /tmp

    if [ -n "$GITHUB_TOKEN" ]; then
        curl -H "Authorization: token $GITHUB_TOKEN" \
             -H "Accept: application/vnd.github.v3+json" \
             -L "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$to_version" \
             -o release-info.json

        BUILD_URL=$(cat release-info.json | grep -o '"browser_download_url": "[^"]*portfolio-build[^"]*"' | cut -d'"' -f4)

        if [ -n "$BUILD_URL" ]; then
            curl -H "Authorization: token $GITHUB_TOKEN" -L "$BUILD_URL" -o "portfolio-build-$to_version.zip"
        else
            error "Build artifact not found in release"
            exit 1
        fi
    else
        curl -L "https://github.com/$GITHUB_REPOSITORY/releases/download/$to_version/portfolio-build-$to_version.zip" \
             -o "portfolio-build-$to_version.zip"
    fi

    # Extract new version
    unzip -o "portfolio-build-$to_version.zip" -d "/tmp/portfolio-update"

    # Graceful shutdown
    log "Stopping services..."
    systemctl stop nginx

    # Update files
    log "Updating application files..."
    rm -rf "$DEPLOY_DIR"/*
    cp -r /tmp/portfolio-update/* "$DEPLOY_DIR/"

    # Set permissions
    chown -R www-data:www-data "$DEPLOY_DIR"
    chmod -R 755 "$DEPLOY_DIR"

    # Clean up
    rm -rf /tmp/portfolio-update
    rm -f /tmp/portfolio-build-*.zip
    rm -f /tmp/release-info.json

    # Start services
    log "Starting services..."
    systemctl start nginx

    # Verify update
    sleep 3
    if curl -f -s http://localhost > /dev/null; then
        log "Update completed successfully!"
        log "Portfolio updated from $from_version to $to_version"
    else
        error "Update verification failed"
        exit 1
    fi

    # Clean old backups (keep last 10)
    cd "$BACKUP_DIR"
    ls -t | tail -n +11 | xargs -r rm -rf
}

# Migration functions for specific version updates
migrate_config() {
    local from_version="$1"
    local to_version="$2"

    log "Running configuration migrations from $from_version to $to_version"

    # Add version-specific migration logic here
    # Example:
    # if version_greater "1.0.0" "$from_version" && version_greater "$to_version" "1.0.0"; then
    #     log "Migrating to v1.0.0 configuration format"
    #     # Migration logic here
    # fi

    info "No configuration migrations needed"
}

# Main update function
main() {
    local target_version="${1:-latest}"

    if [ "$target_version" = "latest" ]; then
        error "Please specify a target version"
        echo "Usage: $0 <version>"
        echo "Example: $0 v1.2.3"
        exit 1
    fi

    local current_version=$(get_current_version)

    log "Starting update process..."
    log "Current version: $current_version"
    log "Target version: $target_version"

    # Check if update is needed
    if [ "$current_version" = "$target_version" ]; then
        info "Already running target version $target_version"
        exit 0
    fi

    # Verify we're updating to a newer version
    if [ "$current_version" != "unknown" ] && ! version_greater "$current_version" "$target_version"; then
        error "Target version $target_version is not newer than current version $current_version"
        exit 1
    fi

    # Run migrations if needed
    migrate_config "$current_version" "$target_version"

    # Perform the update
    update_application "$current_version" "$target_version"

    log "Update process completed successfully!"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo"
    exit 1
fi

# Run main function
main "$@"
