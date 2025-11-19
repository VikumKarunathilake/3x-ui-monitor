#!/bin/bash

# 3X-UI Monitor - Uninstall Script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
APP_NAME="3x-ui-monitor"
INSTALL_DIR="/opt/$APP_NAME"

echo -e "${RED}╔══════════════════════════════════════╗${NC}"
echo -e "${RED}║      3X-UI Monitor Uninstaller      ║${NC}"
echo -e "${RED}╚══════════════════════════════════════╝${NC}"

# Confirmation
read -p "Are you sure you want to uninstall 3X-UI Monitor? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Uninstall cancelled${NC}"
    exit 1
fi

echo -e "${YELLOW}🛑 Stopping and removing Docker container...${NC}"
docker stop $APP_NAME 2>/dev/null || true
docker rm $APP_NAME 2>/dev/null || true
docker rmi $APP_NAME 2>/dev/null || true

echo -e "${YELLOW}🗑️ Removing application files...${NC}"
sudo rm -rf $INSTALL_DIR

echo -e "${YELLOW}🔗 Removing management command...${NC}"
sudo rm -f /usr/local/bin/3x-ui-monitor

echo -e "${YELLOW}🌐 Removing Nginx configuration...${NC}"
sudo rm -f /etc/nginx/sites-available/$APP_NAME
sudo rm -f /etc/nginx/sites-enabled/$APP_NAME

# Restart nginx if it exists
if systemctl is-active --quiet nginx; then
    sudo systemctl reload nginx
fi

echo -e "${YELLOW}🔒 Removing SSL certificates...${NC}"
if command -v certbot &> /dev/null; then
    read -p "Enter domain to remove SSL certificate (or press enter to skip): " DOMAIN
    if [ ! -z "$DOMAIN" ]; then
        sudo certbot delete --cert-name $DOMAIN --non-interactive 2>/dev/null || true
    fi
fi

echo -e "${YELLOW}🧹 Cleaning up Docker...${NC}"
docker system prune -f

echo -e "${GREEN}✅ 3X-UI Monitor has been completely uninstalled${NC}"
echo -e "${YELLOW}📋 Optional cleanup (run manually if needed):${NC}"
echo -e "   ${YELLOW}sudo apt remove nginx certbot python3-certbot-nginx${NC}"
echo -e "   ${YELLOW}sudo apt autoremove${NC}"