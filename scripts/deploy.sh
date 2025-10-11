#!/bin/bash

# Google Cloud VM Deployment Script
# This script runs on the VM to deploy/update the portfolio application

set -e

# Configuration
PROJECT_NAME="portfolio"
REPO_URL="https://github.com/$GITHUB_REPOSITORY"
DEPLOY_DIR="/var/www/portfolio"
BACKUP_DIR="/var/backups/portfolio"
SERVICE_NAME="portfolio"
NODE_VERSION="18"
LOG_FILE="/var/log/portfolio-deploy.log"

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

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing system dependencies..."

    # Update package list
    apt-get update -y

    # Install required packages
    apt-get install -y curl wget git unzip nginx

    # Install Node.js using NodeSource repository
    if ! command -v node &> /dev/null; then
        log "Installing Node.js $NODE_VERSION..."
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
        apt-get install -y nodejs
    fi

    # Install yarn
    if ! command -v yarn &> /dev/null; then
        log "Installing Yarn..."
        npm install -g yarn
    fi

    # Install PM2 for process management
    if ! command -v pm2 &> /dev/null; then
        log "Installing PM2..."
        npm install -g pm2
    fi

    log "Dependencies installed successfully"
}

# Create necessary directories
setup_directories() {
    log "Setting up directories..."

    mkdir -p "$DEPLOY_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "/var/log"

    # Set proper permissions
    chown -R www-data:www-data "$DEPLOY_DIR"

    log "Directories created successfully"
}

# Backup current deployment
backup_current() {
    if [ -d "$DEPLOY_DIR" ] && [ "$(ls -A $DEPLOY_DIR)" ]; then
        log "Creating backup of current deployment..."

        BACKUP_NAME="portfolio-backup-$(date +%Y%m%d-%H%M%S)"
        cp -r "$DEPLOY_DIR" "$BACKUP_DIR/$BACKUP_NAME"

        # Keep only last 5 backups
        cd "$BACKUP_DIR"
        ls -t | tail -n +6 | xargs -r rm -rf

        log "Backup created: $BACKUP_DIR/$BACKUP_NAME"
    else
        info "No existing deployment found, skipping backup"
    fi
}

# Download and extract release
download_release() {
    local version="$1"
    log "Downloading release version: $version"

    cd /tmp

    # Download the release artifacts
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -H "Authorization: token $GITHUB_TOKEN" \
             -H "Accept: application/vnd.github.v3+json" \
             -L "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$version" \
             -o release-info.json

        # Extract download URL for build artifacts
        BUILD_URL=$(cat release-info.json | grep -o '"browser_download_url": "[^"]*portfolio-build[^"]*"' | cut -d'"' -f4)

        if [ -n "$BUILD_URL" ]; then
            curl -H "Authorization: token $GITHUB_TOKEN" -L "$BUILD_URL" -o "portfolio-build-$version.zip"
        else
            error "Build artifact not found in release"
            exit 1
        fi
    else
        # Fallback to public download
        curl -L "https://github.com/$GITHUB_REPOSITORY/releases/download/$version/portfolio-build-$version.zip" \
             -o "portfolio-build-$version.zip"
    fi

    # Extract the build
    log "Extracting build files..."
    unzip -o "portfolio-build-$version.zip" -d "/tmp/portfolio-new"

    log "Release downloaded and extracted successfully"
}

# Deploy the application
deploy_application() {
    log "Deploying application..."

    # Stop the current service
    systemctl stop nginx || true
    pm2 stop "$SERVICE_NAME" || true

    # Clear existing deployment directory
    rm -rf "$DEPLOY_DIR"/*

    # Copy new files
    cp -r /tmp/portfolio-new/* "$DEPLOY_DIR/"

    # Set proper permissions
    chown -R www-data:www-data "$DEPLOY_DIR"
    chmod -R 755 "$DEPLOY_DIR"

    # Clean up temporary files
    rm -rf /tmp/portfolio-new
    rm -f /tmp/portfolio-build-*.zip
    rm -f /tmp/release-info.json

    log "Application deployed successfully"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."

    cat > /etc/nginx/sites-available/portfolio << EOF
server {
    listen 80;
    listen [::]:80;

    server_name _;
    root $DEPLOY_DIR;
    index index.html index.htm;

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
    }

    # Handle React Router
    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

    # Enable the site
    ln -sf /etc/nginx/sites-available/portfolio /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Test nginx configuration
    nginx -t

    log "Nginx configured successfully"
}

# Start services
start_services() {
    log "Starting services..."

    # Start and enable nginx
    systemctl start nginx
    systemctl enable nginx

    # Create PM2 ecosystem file for monitoring (optional)
    cat > "$DEPLOY_DIR/ecosystem.config.js" << EOF
module.exports = {
  apps: [{
    name: '$SERVICE_NAME',
    script: 'serve',
    args: '-s build -l 3000',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production'
    }
  }]
};
EOF

    log "Services started successfully"
}

# Health check
health_check() {
    log "Performing health check..."

    # Wait a moment for services to start
    sleep 5

    # Check if nginx is running
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx is running"
    else
        error "✗ Nginx is not running"
        return 1
    fi

    # Check if the site is accessible
    if curl -f -s http://localhost > /dev/null; then
        log "✓ Website is accessible"
    else
        error "✗ Website is not accessible"
        return 1
    fi

    log "Health check passed"
}

# Rollback function
rollback() {
    error "Deployment failed, attempting rollback..."

    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -n 1)

    if [ -n "$LATEST_BACKUP" ]; then
        log "Rolling back to: $LATEST_BACKUP"

        systemctl stop nginx || true
        rm -rf "$DEPLOY_DIR"/*
        cp -r "$BACKUP_DIR/$LATEST_BACKUP"/* "$DEPLOY_DIR/"
        chown -R www-data:www-data "$DEPLOY_DIR"
        systemctl start nginx

        log "Rollback completed"
    else
        error "No backup found for rollback"
    fi
}

# Main deployment function
main() {
    local version="${1:-latest}"

    log "Starting deployment of portfolio version: $version"

    # Set trap for error handling
    trap rollback ERR

    check_permissions
    install_dependencies
    setup_directories
    backup_current
    download_release "$version"
    deploy_application
    configure_nginx
    start_services
    health_check

    log "Deployment completed successfully!"
    log "Portfolio is now available at: http://$(curl -s ifconfig.me)"

    # Clear the trap
    trap - ERR
}

# Run main function with provided arguments
main "$@"
