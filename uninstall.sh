#!/bin/bash

# 3X-UI Monitor - Uninstall Script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_NAME="3x-ui-monitor"
INSTALL_DIR="/opt/$APP_NAME"
NGINX_SITE_CONF="/etc/nginx/sites-available/$APP_NAME"
NGINX_SITE_ENABLED="/etc/nginx/sites-enabled/$APP_NAME"
MANAGEMENT_SCRIPT="/usr/local/bin/$APP_NAME"

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       3X-UI Monitor Uninstaller      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

echo -e "${YELLOW}🛑 Stopping application...${NC}"
if [ -f "$INSTALL_DIR/app.pid" ]; then
    PID=$(cat "$INSTALL_DIR/app.pid")
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo -e "${GREEN}✅ Application stopped (PID: $PID)${NC}"
    else
        echo -e "${YELLOW}⚠️ Application PID file found, but process not running.${NC}"
    fi
    rm -f "$INSTALL_DIR/app.pid"
else
    echo -e "${YELLOW}⚠️ Application not running or PID file not found.${NC}"
fi

echo -e "${YELLOW}🗑️ Removing management script symlink...${NC}"
if [ -L "$MANAGEMENT_SCRIPT" ]; then
    rm "$MANAGEMENT_SCRIPT"
    echo -e "${GREEN}✅ Symlink removed: $MANAGEMENT_SCRIPT${NC}"
else
    echo -e "${YELLOW}⚠️ Management script symlink not found: $MANAGEMENT_SCRIPT${NC}"
fi

echo -e "${YELLOW}🗑️ Removing application directory: $INSTALL_DIR...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✅ Application directory removed.${NC}"
else
    echo -e "${YELLOW}⚠️ Application directory not found: $INSTALL_DIR${NC}"
fi

echo -e "${YELLOW}🧹 Cleaning up Nginx and Certbot configurations (if present)...${NC}"

# Try to determine if Nginx was configured by this installer by checking for the config file
if [ -f "$NGINX_SITE_CONF" ]; then
    # Get domain from Nginx config, if possible
    DOMAIN=$(grep "server_name" "$NGINX_SITE_CONF" | awk '{print $2}' | sed 's/;//')
    if [ ! -z "$DOMAIN" ]; then
        echo -e "${YELLOW}Revoking Certbot certificate for $DOMAIN...${NC}"
        # Attempt to revoke certificate. This might require user confirmation if --non-interactive is not used
        # For an uninstall, it's better to revoke if we know it was installed by us.
        # However, certbot delete also revokes and cleans up, which is more robust.
        certbot delete --non-interactive --cert-name "$DOMAIN" || echo -e "${YELLOW}⚠️ Failed to delete cert for $DOMAIN. Manual intervention may be needed.${NC}"
    fi

    echo -e "${YELLOW}Removing Nginx configuration files...${NC}"
    if [ -L "$NGINX_SITE_ENABLED" ]; then
        rm "$NGINX_SITE_ENABLED"
        echo -e "${GREEN}✅ Nginx site enabled symlink removed.${NC}"
    fi
    rm -f "$NGINX_SITE_CONF"
    echo -e "${GREEN}✅ Nginx site configuration removed.${NC}"
    
    echo -e "${YELLOW}Restarting Nginx...${NC}"
    systemctl reload nginx || echo -e "${RED}❌ Failed to reload Nginx. Manual check required.${NC}"
else
    echo -e "${YELLOW}⚠️ Nginx configuration for $APP_NAME not found. Skipping Nginx/Certbot cleanup.${NC}"
fi

echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Uninstallation Complete!      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo -e "${YELLOW}Node.js and other system-wide dependencies (like Nginx/Certbot) were not removed.${NC}"
echo -e "${YELLOW}Please remove them manually if they are no longer needed.${NC}"
