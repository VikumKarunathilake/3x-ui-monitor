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
    
    read -rp "Enter domain name for SSL (or press Enter to skip SSL): " input_domain
    DOMAIN_NAME="${input_domain}"
    
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
    
    # List of required dependencies
    DEPENDENCIES=("curl" "sudo" "git")
    
    # Check if each dependency is installed
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log "$dep is not installed. Installing..."
            sudo apt-get install -y "$dep" || { error "Failed to install $dep. Exiting."; }
        else
            log "$dep is already installed."
        fi
    done
}

# ------------------------
# Node.js
# ------------------------
install_nodejs() {
    log "Installing Node.js 24..."
    
    # Check if curl is installed
    if ! command -v curl &>/dev/null; then
        error "curl is required for this step, but it's not installed. Exiting."
    fi
    
    # Fetch Node.js setup script
    log "Fetching Node.js setup script..."
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - || { error "Failed to fetch Node.js setup script. Exiting."; }
    
    # Install Node.js and build-essential
    log "Installing Node.js and build-essential..."
    sudo apt-get install -y nodejs build-essential || { error "Failed to install Node.js or build-essential. Exiting."; }
    
    # Verify Node.js installation
    log "Verifying Node.js installation..."
    node_version=$(node -v)
    if [[ $? -eq 0 ]]; then
        log "Node.js $node_version successfully installed."
    else
        error "Node.js installation failed. Exiting."
    fi
}

# ------------------------
# System user
# ------------------------
setup_user() {
    # Check if the user already exists
    if id "$USER_NAME" &>/dev/null; then
        log "User $USER_NAME already exists."
    else
        # Create system user with specific home directory and no shell access
        log "Creating system user $USER_NAME..."
        sudo useradd --system --shell /bin/false --home-dir "$INSTALL_DIR" "$USER_NAME" || { error "Failed to create user $USER_NAME. Exiting."; }
        
        # Ensure the user's home directory has the correct permissions
        sudo chown -R "$USER_NAME:$USER_NAME" "$INSTALL_DIR" || { error "Failed to set permissions for $USER_NAME's home directory. Exiting."; }
    fi
}

# ------------------------
# Clone repository
# ------------------------
clone_repository() {
    # Ensure git is installed
    if ! command -v git &>/dev/null; then
        error "git is not installed. Exiting."
    fi
    
    # Create the directory if it doesn't exist and set proper ownership
    log "Setting up the repository directory..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "$USER:$USER" "$INSTALL_DIR"
    
    # Check if the directory is already a git repository
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log "Repository already exists. Pulling the latest changes..."
        cd "$INSTALL_DIR" && git pull || { error "Failed to pull latest changes. Exiting."; }
    else
        log "Cloning the repository from $REPO_URL..."
        git clone "$REPO_URL" "$INSTALL_DIR" || { error "Failed to clone repository. Exiting."; }
    fi
}

# ------------------------
# Install npm packages
# ------------------------
install_dependencies() {
    # Change to the install directory
    cd "$INSTALL_DIR" || { error "Failed to enter directory $INSTALL_DIR. Exiting."; }
    
    # Check if npm is installed
    if ! command -v npm &>/dev/null; then
        error "npm is not installed. Please install npm and try again. Exiting."
    fi
    
    # Install pnpm globally if not already installed
    if ! command -v pnpm &>/dev/null; then
        log "Installing pnpm globally..."
        npm install -g pnpm || { error "Failed to install pnpm. Exiting."; }
    else
        log "pnpm is already installed globally."
    fi
    
    # Install project dependencies using pnpm
    log "Installing project dependencies..."
    pnpm install || { error "pnpm install failed. Exiting."; }
    
    # Build the project
    log "Building the project..."
    pnpm run build || { error "Build failed. Exiting."; }
    
    # Ensure executable permissions for bin files in node_modules
    log "Setting executable permissions for bin files..."
    chmod +x node_modules/.bin/* || { error "Failed to set permissions for node_modules/.bin. Exiting."; }
    
    log "Dependencies installed and build completed successfully."
}

# ------------------------
# Environment file
# ------------------------
setup_environment() {
    log "Creating environment configuration file at $CONFIG_FILE..."
    
    # Check if necessary variables are set
    if [[ -z "$PORT" || -z "$DB_PATH" || -z "$USER_NAME" ]]; then
        error "Required environment variables (PORT, DB_PATH, USER_NAME) are not set. Exiting."
    fi
    
    # Create the environment configuration file
    cat > "$CONFIG_FILE" << EOF
PORT=$PORT
DB_PATH=$DB_PATH
NODE_ENV=production
EOF
    
    # Ensure correct ownership and permissions
    log "Setting ownership and permissions for the configuration file..."
    sudo chown "$USER_NAME:$USER_NAME" "$CONFIG_FILE" || { error "Failed to set ownership for $CONFIG_FILE. Exiting."; }
    sudo chmod 600 "$CONFIG_FILE" || { error "Failed to set permissions for $CONFIG_FILE. Exiting."; }
    
    log "Environment configuration file created successfully at $CONFIG_FILE."
}

# ------------------------
# Database permissions
# ------------------------
setup_database() {
    # Create the directory if it doesn't exist
    sudo mkdir -p "$(dirname $DB_PATH)"
    sudo chown -R "$USER_NAME:$USER_NAME" "$(dirname $DB_PATH)"
    
    # Give all permissions (read, write, and execute) to the directory
    sudo chmod 777 "$(dirname $DB_PATH)" || { error "Failed to set permissions for the database directory. Exiting."; }
    
    # Give all permissions to the database file if it exists
    if [[ -f "$DB_PATH" ]]; then
        sudo chmod 777 "$DB_PATH" || { error "Failed to set permissions for $DB_PATH. Exiting."; }
    fi
    
    log "Database directory and file permissions set to 777."
}

# ------------------------
# Nginx
# ------------------------
install_nginx() {
    # Check if Nginx is already installed
    if ! command -v nginx &>/dev/null; then
        log "Installing Nginx..."
        sudo apt-get install -y nginx || { error "Failed to install Nginx. Exiting."; }
    else
        log "Nginx is already installed."
    fi
    
    # Configure Nginx for reverse proxy
    if [[ -n "$DOMAIN_NAME" && "$USE_SSL" == true ]]; then
        log "Setting up Nginx configuration for SSL on port 81..."
        
        # Configure Nginx for SSL on port 81 and HTTP on user port
        cat > "$NGINX_CONF" << EOF
# HTTP server for direct access on user port
server {
    listen $PORT;
    server_name localhost;

    client_max_body_size 10M;
    large_client_header_buffers 4 16k;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}

server {
    listen 81 ssl;
    server_name $DOMAIN_NAME;

    client_max_body_size 10M;
    large_client_header_buffers 4 16k;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
        
        # Enable the site and restart Nginx
        sudo ln -sf "$NGINX_CONF" "$NGINX_ENABLED_CONF" || { error "Failed to create Nginx symlink. Exiting."; }
        sudo nginx -t || { error "Nginx configuration test failed. Exiting."; }
        sudo systemctl restart nginx || { error "Failed to restart Nginx. Exiting."; }
        sudo systemctl enable nginx || { error "Failed to enable Nginx service. Exiting."; }
        log "Nginx configured: HTTP on port $PORT, HTTPS on port 81."
        
        # Setup SSL with Let's Encrypt
        log "Setting up SSL for $DOMAIN_NAME with Let's Encrypt..."
        sudo apt-get install -y certbot python3-certbot-nginx || { error "Failed to install Certbot. Exiting."; }
        
        # Run Certbot to obtain SSL certificate
        sudo certbot --nginx -d "$DOMAIN_NAME" --email "$SSL_EMAIL" --agree-tos --non-interactive || { error "Failed to obtain SSL certificate. Exiting."; }
        log "SSL setup complete for $DOMAIN_NAME."
        
        # Restart Nginx to apply SSL configuration
        sudo systemctl restart nginx || { error "Failed to restart Nginx after SSL setup. Exiting."; }
        
    else
        log "No SSL configuration requested. Application will run directly on port $PORT."
    fi
}

# ------------------------
# SSL
# ------------------------
check_ssl() {
    if [[ -z "$DOMAIN_NAME" || "$USE_SSL" != true ]]; then
        warn "SSL not configured or not requested. Skipping SSL check."
        return 0
    fi
    
    # Check if SSL certificates are present
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"
    
    if [[ -f "$CERT_PATH" && -f "$KEY_PATH" ]]; then
        log "SSL certificates found for $DOMAIN_NAME."
    else
        warn "SSL certificates not found for $DOMAIN_NAME. Please run certbot to obtain them."
        return 1
    fi
    
    # Test SSL configuration with openssl
    log "Testing SSL connectivity for $DOMAIN_NAME on port 81..."
    ssl_test=$(openssl s_client -connect "$DOMAIN_NAME:81" -servername "$DOMAIN_NAME" </dev/null 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        log "SSL is properly configured for $DOMAIN_NAME on port 81."
    else
        error "SSL configuration failed for $DOMAIN_NAME on port 81. Please check Nginx and Certbot configuration."
        return 1
    fi
    
    # Optionally, check with curl if the server is responding over HTTPS
    log "Verifying SSL response using curl..."
    curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN_NAME:81" | grep -q "200"
    
    if [[ $? -eq 0 ]]; then
        log "Successfully connected to $DOMAIN_NAME over HTTPS on port 81."
    else
        error "Failed to connect to $DOMAIN_NAME over HTTPS on port 81."
        return 1
    fi
}

# ------------------------
# Systemd service
# ------------------------
create_service() {
    log "Creating systemd service for 3X-UI Monitor..."
    
    # Create the service file
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
EnvironmentFile=$CONFIG_FILE
ExecStart=/usr/bin/env PORT=$PORT /usr/bin/pnpm start
Restart=always
RestartSec=3
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Set appropriate permissions for the service file
    sudo chmod 644 "/etc/systemd/system/$SERVICE_NAME.service" || { error "Failed to set permissions for service file. Exiting."; }
    
    # Reload systemd to apply the new service file
    log "Reloading systemd daemon..."
    sudo systemctl daemon-reload || { error "Failed to reload systemd. Exiting."; }
    
    # Enable the service to start on boot
    log "Enabling service $SERVICE_NAME to start on boot..."
    sudo systemctl enable "$SERVICE_NAME" || { error "Failed to enable service $SERVICE_NAME. Exiting."; }
    
    # Start the service
    log "Starting the 3X-UI Monitor service..."
    sudo systemctl start "$SERVICE_NAME" || { error "Failed to start service $SERVICE_NAME. Exiting."; }
    
    log "Service $SERVICE_NAME created and started successfully."
}

# ------------------------
# Run installation
# ------------------------
main() {
    get_user_input || { error "User input failed. Exiting."; }
    check_dependencies || { error "Dependency check failed. Exiting."; }
    install_nodejs || { error "Node.js installation failed. Exiting."; }
    setup_user || { error "User setup failed. Exiting."; }
    clone_repository || { error "Repository cloning failed. Exiting."; }
    install_dependencies || { error "Dependency installation failed. Exiting."; }
    setup_environment || { error "Environment setup failed. Exiting."; }
    setup_database || { error "Database setup failed. Exiting."; }
    install_nginx || { error "Nginx installation and configuration failed. Exiting."; }
    
    if [[ "$USE_SSL" == true ]]; then
        check_ssl || { error "SSL configuration failed. Exiting."; }
    fi
    
    create_service || { error "Service creation failed. Exiting."; }
    
    echo -e "${GREEN}Installation complete!${NC}"
    echo "Service status: $(systemctl is-active $SERVICE_NAME)"
    echo "Run logs with: journalctl -u $SERVICE_NAME -f"
    
    # Final output handling
    if [[ "$USE_SSL" == true ]]; then
        echo "SSL enabled. Access at: https://$DOMAIN_NAME:81"  # SSL URL
        echo "Non-SSL access at: http://$(hostname -I | awk '{print $1}'):$PORT"  # Non-SSL URL with IP
    else
        echo "Access the monitor at: http://$(hostname -I | awk '{print $1}'):$PORT"  # Default HTTP port
    fi
}
main
