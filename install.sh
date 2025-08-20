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
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/VikumKarunathilake/3x-ui-monitor"
INSTALL_DIR="/opt/3x-ui-monitor"
SERVICE_NAME="3x-ui-monitor"
USER_NAME="3x-ui-monitor"
DB_PATH="/var/lib/3x-ui-monitor/data/x-ui.db"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
}

check_dependencies() {
    log "Checking system dependencies..."
    
    local missing_deps=()
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    # Check for sudo
    if ! command -v sudo &> /dev/null; then
        missing_deps+=("sudo")
    fi
    
    # Check for systemd
    if ! command -v systemctl &> /dev/null; then
        missing_deps+=("systemd")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}. Please install them first."
    fi
}

install_nodejs() {
    log "Checking Node.js installation..."
    
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        local node_version=$(node --version | cut -d'v' -f2)
        local major_version=$(echo $node_version | cut -d'.' -f1)
        
        if [[ $major_version -ge 18 ]]; then
            log "Node.js $node_version is already installed"
            return
        else
            warn "Node.js version $node_version is too old. Need version 18 or higher."
        fi
    fi
    
    log "Installing Node.js 18..."
    
    # Install Node.js using NodeSource
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    if ! command -v node &> /dev/null; then
        error "Failed to install Node.js"
    fi
    
    log "Node.js $(node --version) installed successfully"
}

setup_user() {
    log "Setting up system user..."
    
    if ! id "$USER_NAME" &>/dev/null; then
        sudo useradd --system --shell /bin/false --home-dir "$INSTALL_DIR" "$USER_NAME"
        log "Created system user: $USER_NAME"
    else
        log "System user $USER_NAME already exists"
    fi
}

clone_repository() {
    log "Cloning repository..."
    
    # Create installation directory
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown $USER:$USER "$INSTALL_DIR"
    
    # Clone the repository
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        warn "Repository already exists. Pulling latest changes..."
        cd "$INSTALL_DIR"
        git pull origin master
    else
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR"
}

install_dependencies() {
    log "Installing npm dependencies..."
    
    cd "$INSTALL_DIR"
    npm install --production
    
    if [[ $? -ne 0 ]]; then
        error "Failed to install npm dependencies"
    fi
}

setup_database() {
    log "Setting up database directory..."
    
    local db_dir=$(dirname "$DB_PATH")
    sudo mkdir -p "$db_dir"
    sudo chown -R "$USER_NAME:$USER_NAME" "$db_dir"
    sudo chmod 755 "$db_dir"
    
    # Check if x-ui.db exists and is readable
    if [[ -f "$DB_PATH" ]]; then
        if sudo test -r "$DB_PATH"; then
            log "Database file found and is readable: $DB_PATH"
        else
            warn "Database file exists but is not readable. Adjusting permissions..."
            sudo chmod 644 "$DB_PATH"
        fi
    else
        warn "Database file not found: $DB_PATH"
        warn "Please ensure your 3X-UI database exists at this location"
    fi
}

create_service() {
    log "Creating systemd service..."
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    sudo tee "$service_file" > /dev/null << EOF
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

# Security
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    log "Systemd service created: $service_file"
}

setup_permissions() {
    log "Setting up permissions..."
    
    # Change ownership of installation directory
    sudo chown -R "$USER_NAME:$USER_NAME" "$INSTALL_DIR"
    
    # Set appropriate permissions
    sudo chmod 755 "$INSTALL_DIR"
    sudo find "$INSTALL_DIR" -type f -exec chmod 644 {} \;
    sudo chmod 755 "$INSTALL_DIR/node_modules/.bin/*" 2>/dev/null || true
}

build_application() {
    log "Building application..."
    
    cd "$INSTALL_DIR"
    npm run build
    
    if [[ $? -ne 0 ]]; then
        error "Failed to build application"
    fi
}

start_service() {
    log "Starting service..."
    
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    
    # Wait a bit for service to start
    sleep 3
    
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Service started successfully"
    else
        error "Failed to start service. Check logs with: journalctl -u $SERVICE_NAME"
    fi
}

show_success() {
    local ip_address=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}"
    echo "================================================"
    echo "  3X-UI Monitor Installation Complete!"
    echo "================================================"
    echo -e "${NC}"
    echo "Service: $SERVICE_NAME"
    echo "Installation Directory: $INSTALL_DIR"
    echo "Database Path: $DB_PATH"
    echo "Service Status: $(sudo systemctl is-active $SERVICE_NAME)"
    echo ""
    echo "Access the application at:"
    echo -e "  ${BLUE}http://${ip_address}:3000${NC}"
    echo ""
    echo "Management commands:"
    echo "  Start:    sudo systemctl start $SERVICE_NAME"
    echo "  Stop:     sudo systemctl stop $SERVICE_NAME"
    echo "  Restart:  sudo systemctl restart $SERVICE_NAME"
    echo "  Status:   sudo systemctl status $SERVICE_NAME"
    echo "  Logs:     journalctl -u $SERVICE_NAME -f"
    echo ""
    echo -e "${YELLOW}Note: Ensure your 3X-UI database is accessible at $DB_PATH${NC}"
    echo -e "${GREEN}================================================"
    echo -e "${NC}"
}

main() {
    echo -e "${GREEN}"
    echo "================================================"
    echo "  3X-UI Monitor Installation Script"
    echo "  License: CC-BY-ND"
    echo "================================================"
    echo -e "${NC}"
    
    # Check prerequisites
    check_root
    check_dependencies
    
    # Installation steps
    install_nodejs
    setup_user
    clone_repository
    install_dependencies
    setup_database
    create_service
    setup_permissions
    build_application
    start_service
    
    # Show success message
    show_success
}

# Handle script interruption
trap 'error "Installation interrupted by user"; exit 1' INT

# Run main function
main "$@"