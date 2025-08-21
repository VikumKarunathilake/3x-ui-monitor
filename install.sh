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

info() {
    echo -e "${CYAN}[INPUT]${NC} $1"
}

get_user_input() {
    echo -e "${CYAN}"
    echo "================================================"
    echo "  3X-UI Monitor Configuration Setup"
    echo "================================================"
    echo -e "${NC}"
    
    # Get port number
    while true; do
        read -rp "Enter the port number for 3X-UI Monitor (default: 3000): " input_port
        if [[ -z "$input_port" ]]; then
            PORT="3000"
            break
        elif [[ "$input_port" =~ ^[0-9]+$ ]] && [ "$input_port" -ge 1024 ] && [ "$input_port" -le 65535 ]; then
            PORT="$input_port"
            break
        else
            echo -e "${YELLOW}[WARN]${NC} Invalid port number. Please enter a number between 1024 and 65535."
        fi
    done
    
    # Get domain name or IP
    read -rp "Enter your domain name (e.g., monitor.example.com) or press Enter to use IP address: " input_domain
    if [[ -n "$input_domain" ]]; then
        DOMAIN_NAME="$input_domain"
        
        # Ask about SSL
        read -rp "Do you want to enable SSL with Let's Encrypt? (y/N): " ssl_choice
        if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
            USE_SSL=true
            while true; do
                read -rp "Enter your email address for Let's Encrypt SSL certificates: " email_input
                if [[ -n "$email_input" ]]; then
                    SSL_EMAIL="$email_input"
                    break
                else
                    echo -e "${YELLOW}[WARN]${NC} Email address is required for SSL certificates."
                fi
            done
        fi
    fi
    
    # Confirm database path
    echo -e "${CYAN}[INPUT]${NC} Current database path: $DB_PATH"
    read -rp "Is this the correct path to your x-ui.db file? (Y/n): " db_confirm
    if [[ "$db_confirm" =~ ^[Nn]$ ]]; then
        read -rp "Enter the full path to your x-ui.db file: " custom_db_path
        if [[ -n "$custom_db_path" ]]; then
            DB_PATH="$custom_db_path"
        fi
    fi
    
    # Summary
    echo -e "${GREEN}"
    echo "Configuration Summary:"
    echo "---------------------"
    echo "Port: $PORT"
    if [[ -n "$DOMAIN_NAME" ]]; then
        echo "Domain: $DOMAIN_NAME"
        echo "SSL: $USE_SSL"
        [[ "$USE_SSL" == true ]] && echo "SSL Email: $SSL_EMAIL"
    else
        echo "Access: IP address (port $PORT)"
    fi
    echo "Database: $DB_PATH"
    echo -e "${NC}"
    
    read -rp "Press Enter to continue with installation or Ctrl+C to cancel... "
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

setup_environment() {
    log "Setting up environment configuration..."
    
    # Create .env file
    sudo tee "$CONFIG_FILE" > /dev/null << EOF
PORT=$PORT
DB_PATH=$DB_PATH
NODE_ENV=production
EOF

    sudo chown "$USER_NAME:$USER_NAME" "$CONFIG_FILE"
    sudo chmod 600 "$CONFIG_FILE"
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
            sudo chown "$USER_NAME:$USER_NAME" "$DB_PATH"
            sudo chmod 644 "$DB_PATH"
        fi
    else
        warn "Database file not found: $DB_PATH"
        warn "Please ensure your 3X-UI database exists at this location"
        read -rp "Press Enter to continue or Ctrl+C to abort... "
    fi
}

install_nginx() {
    if [[ -z "$DOMAIN_NAME" ]]; then
        return
    fi
    
    log "Installing and configuring Nginx..."
    
    # Install Nginx
    if ! command -v nginx &> /dev/null; then
        sudo apt-get install -y nginx
    fi
    
    # Create Nginx configuration
    sudo tee "$NGINX_CONF" > /dev/null << EOF
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
    
    # Enable site
    sudo ln -sf "$NGINX_CONF" "$NGINX_ENABLED_CONF"
    
    # Test Nginx configuration
    sudo nginx -t
    
    # Restart Nginx
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    log "Nginx configuration complete"
}

setup_ssl() {
    if [[ "$USE_SSL" != true ]] || [[ -z "$DOMAIN_NAME" ]]; then
        return
    fi
    
    log "Setting up SSL with Let's Encrypt..."
    
    # Install Certbot
    if ! command -v certbot &> /dev/null; then
        sudo apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Obtain SSL certificate
    sudo certbot --nginx -d "$DOMAIN_NAME" --email "$SSL_EMAIL" --agree-tos --non-interactive
    
    # Set up automatic renewal
    (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | sudo crontab -
    
    log "SSL setup complete"
}

create_service() {
    log "Creating systemd service..."
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=3X-UI Monitor Service
After=network.target
$( [[ -n "$DOMAIN_NAME" ]] && echo "After=nginx.service" )

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/node_modules/.bin:/usr/bin
EnvironmentFile=$CONFIG_FILE
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
    sleep 5
    
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Service started successfully"
    else
        error "Failed to start service. Check logs with: journalctl -u $SERVICE_NAME"
    fi
}

show_success() {
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
    
    if [[ -n "$DOMAIN_NAME" ]]; then
        local protocol="http"
        [[ "$USE_SSL" == true ]] && protocol="https"
        echo "Access the application at:"
        echo -e "  ${BLUE}${protocol}://${DOMAIN_NAME}${NC}"
    else
        local ip_address=$(hostname -I | awk '{print $1}')
        echo "Access the application at:"
        echo -e "  ${BLUE}http://${ip_address}:${PORT}${NC}"
    fi
    
    echo ""
    echo "Management commands:"
    echo "  Start:    sudo systemctl start $SERVICE_NAME"
    echo "  Stop:     sudo systemctl stop $SERVICE_NAME"
    echo "  Restart:  sudo systemctl restart $SERVICE_NAME"
    echo "  Status:   sudo systemctl status $SERVICE_NAME"
    echo "  Logs:     journalctl -u $SERVICE_NAME -f"
    echo ""
    
    if [[ "$USE_SSL" == true ]]; then
        echo "SSL Certificate: Managed by Let's Encrypt"
        echo "SSL Renewal: Automatic (cron job configured)"
        echo ""
    fi
    
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
    
    # Get user configuration
    get_user_input
    
    # Check prerequisites
    check_dependencies
    
    # Installation steps
    install_nodejs
    setup_user
    clone_repository
    install_dependencies
    setup_environment
    setup_database
    install_nginx
    setup_ssl
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