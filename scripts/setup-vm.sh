#!/bin/bash

# Google Cloud VM Initial Setup Script
# Run this script once on a fresh VM to prepare it for portfolio deployments

set -e

# Configuration
PROJECT_NAME="portfolio"
DEPLOY_DIR="/var/www/portfolio"
BACKUP_DIR="/var/backups/portfolio"
SCRIPTS_DIR="/opt/portfolio-scripts"
LOG_FILE="/var/log/portfolio-setup.log"

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

# Check if running as root
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget git unzip build-essential software-properties-common
    log "System packages updated successfully"
}

# Install Node.js and Yarn
install_nodejs() {
    log "Installing Node.js and Yarn..."

    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs

    # Install Yarn
    npm install -g yarn

    # Install PM2 for process management
    npm install -g pm2

    # Verify installations
    node_version=$(node --version)
    yarn_version=$(yarn --version)
    pm2_version=$(pm2 --version)

    log "Node.js version: $node_version"
    log "Yarn version: $yarn_version"
    log "PM2 version: $pm2_version"
}

# Install and configure Nginx
install_nginx() {
    log "Installing and configuring Nginx..."

    apt-get install -y nginx

    # Create basic configuration
    cat > /etc/nginx/sites-available/portfolio << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;
    root /var/www/portfolio;
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
        access_log off;
    }

    # Handle React Router
    location / {
        try_files $uri $uri/ /index.html;
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

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # Remove default site
    rm -f /etc/nginx/sites-enabled/default

    # Enable portfolio site
    ln -sf /etc/nginx/sites-available/portfolio /etc/nginx/sites-enabled/

    # Test configuration
    nginx -t

    log "Nginx installed and configured successfully"
}

# Setup directories and permissions
setup_directories() {
    log "Setting up directories and permissions..."

    # Create directories
    mkdir -p "$DEPLOY_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "/var/log"

    # Set permissions
    chown -R www-data:www-data "$DEPLOY_DIR"
    chown -R root:root "$BACKUP_DIR"
    chown -R root:root "$SCRIPTS_DIR"

    chmod 755 "$DEPLOY_DIR"
    chmod 755 "$BACKUP_DIR"
    chmod 755 "$SCRIPTS_DIR"

    log "Directories created and permissions set"
}

# Configure firewall
setup_firewall() {
    log "Configuring firewall..."

    # Install ufw if not present
    apt-get install -y ufw

    # Reset to defaults
    ufw --force reset

    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH
    ufw allow ssh

    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp

    # Enable firewall
    ufw --force enable

    log "Firewall configured successfully"
}

# Setup log rotation
setup_logrotate() {
    log "Setting up log rotation..."

    cat > /etc/logrotate.d/portfolio << 'EOF'
/var/log/portfolio*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    create 0644 root root
}
EOF

    log "Log rotation configured"
}

# Create systemd service for portfolio monitoring
create_systemd_service() {
    log "Creating systemd service for portfolio monitoring..."

    cat > /etc/systemd/system/portfolio-monitor.service << 'EOF'
[Unit]
Description=Portfolio Application Monitor
After=network.target nginx.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/portfolio
ExecStart=/usr/bin/node -e "const http = require('http'); const server = http.createServer((req, res) => { res.writeHead(200); res.end('Portfolio Monitor Running'); }); server.listen(3001, () => console.log('Monitor running on port 3001'));"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable portfolio-monitor

    log "Systemd service created"
}

# Create a placeholder index.html
create_placeholder() {
    log "Creating placeholder page..."

    cat > "$DEPLOY_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Portfolio - Deployment Ready</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 40px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-direction: column;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        h1 { margin-bottom: 20px; }
        .status { color: #4ade80; font-weight: bold; }
        .info { margin-top: 20px; opacity: 0.8; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Portfolio Server</h1>
        <p class="status">✅ VM Setup Complete - Ready for Deployment</p>
        <p class="info">
            This server is configured and ready to receive your portfolio application.<br>
            Deploy your application using the GitHub Actions workflow.
        </p>
        <p class="info">
            <strong>Server IP:</strong> <span id="server-ip">Loading...</span><br>
            <strong>Setup Time:</strong> <span id="setup-time"></span>
        </p>
    </div>

    <script>
        // Display current time
        document.getElementById('setup-time').textContent = new Date().toLocaleString();

        // Try to get server IP (this will show the client IP, but it's better than nothing)
        fetch('https://api.ipify.org?format=json')
            .then(response => response.json())
            .then(data => {
                document.getElementById('server-ip').textContent = data.ip;
            })
            .catch(() => {
                document.getElementById('server-ip').textContent = 'Available after deployment';
            });
    </script>
</body>
</html>
EOF

    chown www-data:www-data "$DEPLOY_DIR/index.html"
    log "Placeholder page created"
}

# Start services
start_services() {
    log "Starting services..."

    systemctl start nginx
    systemctl enable nginx

    systemctl start portfolio-monitor

    log "Services started and enabled"
}

# Final verification
verify_setup() {
    log "Verifying setup..."

    # Check if nginx is running
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx is running"
    else
        error "✗ Nginx is not running"
        return 1
    fi

    # Check if the placeholder page is accessible
    if curl -f -s http://localhost > /dev/null; then
        log "✓ Web server is accessible"
    else
        error "✗ Web server is not accessible"
        return 1
    fi

    # Check directories
    if [ -d "$DEPLOY_DIR" ] && [ -d "$BACKUP_DIR" ] && [ -d "$SCRIPTS_DIR" ]; then
        log "✓ All directories are created"
    else
        error "✗ Some directories are missing"
        return 1
    fi

    log "Setup verification completed successfully!"
}

# Show setup summary
show_summary() {
    log "Setup Summary:"
    echo ""
    echo "==================== SETUP COMPLETE ===================="
    echo "✅ Google Cloud VM is ready for portfolio deployment"
    echo ""
    echo "📋 What was configured:"
    echo "   • Node.js $(node --version) and Yarn $(yarn --version)"
    echo "   • Nginx web server with portfolio configuration"
    echo "   • PM2 process manager"
    echo "   • Firewall (UFW) with HTTP/HTTPS access"
    echo "   • Log rotation for application logs"
    echo "   • Systemd service for monitoring"
    echo "   • Directory structure and permissions"
    echo ""
    echo "📁 Important directories:"
    echo "   • Application: $DEPLOY_DIR"
    echo "   • Backups: $BACKUP_DIR"
    echo "   • Scripts: $SCRIPTS_DIR"
    echo "   • Logs: /var/log/portfolio*.log"
    echo ""
    echo "🔗 Access your server:"
    echo "   • Web: http://$(curl -s ifconfig.me || echo 'YOUR_VM_IP')"
    echo "   • Health check: http://$(curl -s ifconfig.me || echo 'YOUR_VM_IP')/health"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Configure GitHub secrets for deployment"
    echo "   2. Create a release to trigger automatic deployment"
    echo "   3. Monitor deployment logs in GitHub Actions"
    echo ""
    echo "========================================================="
}

# Main setup function
main() {
    log "Starting Google Cloud VM setup for portfolio deployment..."

    check_permissions
    update_system
    install_nodejs
    install_nginx
    setup_directories
    setup_firewall
    setup_logrotate
    create_systemd_service
    create_placeholder
    start_services
    verify_setup
    show_summary

    log "VM setup completed successfully!"
}

# Run the main function
main "$@"
