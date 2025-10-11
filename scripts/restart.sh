#!/bin/bash

# Portfolio Restart Script
# This script gracefully restarts the portfolio application services

set -e

# Configuration
PROJECT_NAME="portfolio"
DEPLOY_DIR="/var/www/portfolio"
LOG_FILE="/var/log/portfolio-restart.log"

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

# Check if services are running
check_service_status() {
    local service="$1"

    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

# Graceful restart of nginx
restart_nginx() {
    log "Restarting Nginx..."

    # Test configuration first
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log "✓ Nginx reloaded successfully"
    else
        error "Nginx configuration test failed, performing hard restart"
        systemctl restart nginx
        log "✓ Nginx restarted"
    fi
}

# Clear application caches
clear_caches() {
    log "Clearing application caches..."

    # Clear nginx cache if exists
    if [ -d "/var/cache/nginx" ]; then
        rm -rf /var/cache/nginx/*
        log "✓ Nginx cache cleared"
    fi

    # Clear any temporary files
    if [ -d "/tmp/portfolio-*" ]; then
        rm -rf /tmp/portfolio-*
        log "✓ Temporary files cleaned"
    fi

    log "Caches cleared successfully"
}

# Health check after restart
health_check() {
    log "Performing health check..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost > /dev/null; then
            log "✓ Health check passed (attempt $attempt)"
            return 0
        fi

        info "Health check attempt $attempt failed, retrying in 2 seconds..."
        sleep 2
        ((attempt++))
    done

    error "Health check failed after $max_attempts attempts"
    return 1
}

# Get service status
get_status() {
    log "Checking service status..."

    echo "=== Service Status ==="

    if check_service_status nginx; then
        echo "✓ Nginx: Running"
    else
        echo "✗ Nginx: Stopped"
    fi

    # Check if website is accessible
    if curl -f -s http://localhost > /dev/null; then
        echo "✓ Website: Accessible"
    else
        echo "✗ Website: Not accessible"
    fi

    # Show nginx status
    echo -e "\n=== Nginx Status ==="
    systemctl status nginx --no-pager -l

    # Show recent logs
    echo -e "\n=== Recent Nginx Logs ==="
    journalctl -u nginx --no-pager -n 10
}

# Force restart (hard restart)
force_restart() {
    log "Performing force restart..."

    # Stop all services
    systemctl stop nginx || true

    # Kill any remaining processes
    pkill -f nginx || true

    # Clear caches
    clear_caches

    # Start services
    systemctl start nginx

    # Wait and check
    sleep 3
    health_check

    log "Force restart completed"
}

# Graceful restart (default)
graceful_restart() {
    log "Performing graceful restart..."

    # Check current status
    local nginx_running=false

    if check_service_status nginx; then
        nginx_running=true
        log "Nginx is currently running"
    else
        log "Nginx is not running, will start it"
    fi

    # Clear caches first
    clear_caches

    # Restart nginx
    if [ "$nginx_running" = true ]; then
        restart_nginx
    else
        systemctl start nginx
        log "✓ Nginx started"
    fi

    # Health check
    health_check

    log "Graceful restart completed successfully"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -g, --graceful    Perform graceful restart (default)"
    echo "  -f, --force       Perform force restart"
    echo "  -s, --status      Show service status"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Graceful restart"
    echo "  $0 --force        # Force restart"
    echo "  $0 --status       # Show status"
}

# Main function
main() {
    local action="graceful"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--graceful)
                action="graceful"
                shift
                ;;
            -f|--force)
                action="force"
                shift
                ;;
            -s|--status)
                action="status"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    log "Starting restart script with action: $action"

    case $action in
        graceful)
            graceful_restart
            ;;
        force)
            force_restart
            ;;
        status)
            get_status
            ;;
        *)
            error "Unknown action: $action"
            exit 1
            ;;
    esac

    log "Restart script completed"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo"
    exit 1
fi

# Run main function with all arguments
main "$@"
