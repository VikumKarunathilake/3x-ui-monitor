#!/bin/bash

# 3X-UI Monitor Installation Script
# License: Creative Commons Attribution-NoDerivs (CC-BY-ND)
# Author: Vikum_K / CeylonCloud

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/VikumKarunathilake/3x-ui-monitor"
INSTALL_DIR="/opt/3x-ui-monitor"
SERVICE_NAME="3x-ui-monitor"
USER_NAME="3x-ui-monitor"
DB_PATH="/etc/x-ui/x-ui.db"
CONFIG_FILE="$INSTALL_DIR/.env"
NGINX_CONF="/etc/nginx/sites-available/3x-ui-monitor"
NGINX_ENABLED_CONF="/etc/nginx/sites-enabled/3x-ui-monitor"

# User configuration variables
PORT="3000"
DOMAIN_NAME=""
USE_SSL=false
SSL_EMAIL=""

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ------------------------
# User input
# ------------------------
get_user_input() {
    read -rp "Enter port number for 3X-UI Monitor (default: 3000): " input_port
    PORT=${input_port:-3000}

    read -rp "Enter domain name (or press Enter to use IP): " input_domain
    DOMAIN_NAME="$input_domain"

    if [[ -n "$DOMAIN_NAME" ]]; then
        read -rp "Enable SSL with Let's Encrypt? (y/N): " ssl_choice
        [[ "$ssl_choice" =~ ^[Yy]$ ]] && USE_SSL=true && read -rp "Enter SSL email: " SSL_EMAIL
    fi

    echo "Current database path: $DB_PATH"
    read -rp "Is this correct? (Y/n): " db_confirm
    [[ "$db_confirm" =~ ^[Nn]$ ]] && read -rp "Enter full path to x-ui.db: " custom_db && DB_PATH="$custom_db"

    echo -e "${GREEN}\nSummary:\nPort: $PORT\nDatabase: $DB_PATH\nDomain: $DOMAIN_NAME\nSSL: $USE_SSL\nSSL Email: $SSL_EMAIL${NC}"
    read -rp "Press Enter to continue..."
}

# ------------------------
# Dependencies
# ------------------------
check_dependencies() {
    log "Checking dependencies..."
    for dep in curl sudo systemctl git make g++; do
        command -v $dep >/dev/null 2>&1 || sudo apt-get install -y $dep
    done
}

# ------------------------
# Node.js
# ------------------------
install_nodejs() {
    log "Installing Node.js 24..."
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get install -y nodejs build-essential
}

# ------------------------
# System user
# ------------------------
setup_user() {
    id "$USER_NAME" &>/dev/null || sudo useradd --system --shell /bin/false --home-dir "$INSTALL_DIR" "$USER_NAME"
}

# ------------------------
# Clone repository
# ------------------------
clone_repository() {
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown $USER:$USER "$INSTALL_DIR"

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        cd "$INSTALL_DIR" && git pull
    else
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
}

# ------------------------
# Install npm packages
# ------------------------
install_dependencies() {
    cd "$INSTALL_DIR"
    npm install --production || error "npm install failed"
    chmod +x node_modules/.bin/*   # Make sure binaries like 'next' are executable
}

# ------------------------
# Environment file
# ------------------------
setup_environment() {
    cat > "$CONFIG_FILE" << EOF
PORT=$PORT
DB_PATH=$DB_PATH
NODE_ENV=production
EOF
    chown "$USER_NAME:$USER_NAME" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

# ------------------------
# Database permissions
# ------------------------
setup_database() {
    sudo mkdir -p "$(dirname $DB_PATH)"
    sudo chown -R "$USER_NAME:$USER_NAME" "$(dirname $DB_PATH)"
    [[ -f "$DB_PATH" ]] && chmod 644 "$DB_PATH"
}

# ------------------------
# Nginx
# ------------------------
install_nginx() {
    [[ -z "$DOMAIN_NAME" ]] && return
    sudo apt-get install -y nginx
    cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    sudo ln -sf "$NGINX_CONF" "$NGINX_ENABLED_CONF"
    sudo nginx -t
    sudo systemctl restart nginx
    sudo systemctl enable nginx
}

# ------------------------
# SSL
# ------------------------
setup_ssl() {
    [[ "$USE_SSL" != true ]] && return
    sudo apt-get install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d "$DOMAIN_NAME" --email "$SSL_EMAIL" --agree-tos --non-interactive
}

# ------------------------
# Systemd service
# ------------------------
create_service() {
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=3X-UI Monitor Service
After=network.target

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/node_modules/.bin:/usr/bin
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=3
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
}

# ------------------------
# Run installation
# ------------------------
main() {
    get_user_input
    check_dependencies
    install_nodejs
    setup_user
    clone_repository
    install_dependencies
    setup_environment
    setup_database
    install_nginx
    setup_ssl
    create_service

    echo -e "${GREEN}Installation complete!${NC}"
    echo "Service status: $(systemctl is-active $SERVICE_NAME)"
    echo "Run logs with: journalctl -u $SERVICE_NAME -f"
    echo "Access the monitor at: http://$DOMAIN_NAME:$PORT"
    [[ "$USE_SSL" == true ]] && echo "SSL enabled. Access at: https://$DOMAIN_NAME"
}

main
