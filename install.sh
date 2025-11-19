#!/bin/bash

# 3X-UI Monitor - All-in-One Installation Script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_NAME="3x-ui-monitor"
APP_PORT="3000"
INSTALL_DIR="/opt/$APP_NAME"

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        3X-UI Monitor Installer       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ Don't run this script as root${NC}"
   exit 1
fi

# Get user input
read -p "Enter your domain (optional, press enter to skip SSL): " DOMAIN
if [ ! -z "$DOMAIN" ]; then
    read -p "Enter your email for SSL certificate: " EMAIL
fi



echo -e "${YELLOW}📁 Setting up application directory...${NC}"
sudo mkdir -p $INSTALL_DIR
sudo chown $USER:$USER $INSTALL_DIR

echo -e "${YELLOW}📥 Cloning repository...${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
    cd $INSTALL_DIR
    git pull origin main
else
    git clone https://github.com/VikumKarunathilake/3x-ui-monitor.git $INSTALL_DIR
        cd $INSTALL_DIR
    fi
    
    echo -e "${YELLOW}🛠️ Installing Node.js...${NC}"
    # Install Node.js (if not already installed)
    if ! command -v node &> /dev/null; then
        echo -e "${YELLOW}Installing Node.js...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        echo -e "${GREEN}✅ Node.js installed${NC}"
    else
        echo -e "${GREEN}✅ Node.js already installed${NC}"
    fi    
    echo -e "${YELLOW}🔨 Building and starting application...${NC}"
cd $INSTALL_DIR
npm install
npm run build
nohup npm start > app.log 2>&1 &
echo $! > app.pid
echo -e "${GREEN}✅ Application started${NC}"
if [ ! -z "$DOMAIN" ]; then
    echo -e "${YELLOW}🔒 Setting up SSL...${NC}"
    
    # Install Nginx and Certbot
    sudo apt update
    sudo apt install -y nginx certbot python3-certbot-nginx
    
    # Configure Nginx
    sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$APP_PORT;
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
    sudo ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    # Get SSL certificate
    sudo certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive --redirect
    
    # Setup auto-renewal
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
    
    echo -e "${GREEN}🌐 Application available at: https://$DOMAIN${NC}"
else
    echo -e "${GREEN}🌐 Application available at: http://$(curl -s ifconfig.me):$APP_PORT${NC}"
fi

# Create management script
cat > $INSTALL_DIR/manage.sh << 'EOF'
#!/bin/bash
APP_NAME="3x-ui-monitor"
INSTALL_DIR="/opt/$APP_NAME"

case "$1" in
    start)
        if [ -f "$INSTALL_DIR/app.pid" ] && kill -0 $(cat "$INSTALL_DIR/app.pid") 2>/dev/null; then
            echo "✅ $APP_NAME is already running."
        else
            cd $INSTALL_DIR
            nohup npm start > app.log 2>&1 &
            echo $! > app.pid
            echo "✅ Started $APP_NAME"
        fi
        ;;
    stop)
        if [ -f "$INSTALL_DIR/app.pid" ] && kill -0 $(cat "$INSTALL_DIR/app.pid") 2>/dev/null; then
            kill $(cat "$INSTALL_DIR/app.pid")
            rm "$INSTALL_DIR/app.pid"
            echo "🛑 Stopped $APP_NAME"
        else
            echo "❌ $APP_NAME is not running."
        fi
        ;;
    restart)
        if [ -f "$INSTALL_DIR/app.pid" ] && kill -0 $(cat "$INSTALL_DIR/app.pid") 2>/dev/null; then
            kill $(cat "$INSTALL_DIR/app.pid")
            rm "$INSTALL_DIR/app.pid"
            echo "🛑 Stopped $APP_NAME for restart"
        fi
        cd $INSTALL_DIR
        nohup npm start > app.log 2>&1 &
        echo $! > app.pid
        echo "🔄 Restarted $APP_NAME"
        ;;
    logs)
        if [ -f "$INSTALL_DIR/app.log" ]; then
            tail -f "$INSTALL_DIR/app.log"
        else
            echo "❌ Log file not found: $INSTALL_DIR/app.log"
        fi
        ;;
    update)
        cd $INSTALL_DIR
        git pull origin main
        if [ -f "app.pid" ] && kill -0 $(cat "app.pid") 2>/dev/null; then
            kill $(cat "app.pid")
            rm "app.pid"
            echo "🛑 Stopped $APP_NAME for update"
        fi
        npm install
        npm run build
        nohup npm start > app.log 2>&1 &
        echo $! > app.pid
        echo "🚀 Updated and restarted $APP_NAME"
        ;;
    status)
        if [ -f "$INSTALL_DIR/app.pid" ] && kill -0 $(cat "$INSTALL_DIR/app.pid") 2>/dev/null; then
            echo "✅ $APP_NAME is running with PID $(cat "$INSTALL_DIR/app.pid")"
        else
            echo "❌ $APP_NAME is not running."
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|update|status}"
        exit 1
        ;;
esac
EOF

chmod +x $INSTALL_DIR/manage.sh
sudo ln -sf $INSTALL_DIR/manage.sh /usr/local/bin/3x-ui-monitor

echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation Complete!       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo -e "${YELLOW}📋 Management commands:${NC}"
echo -e "   ${BLUE}3x-ui-monitor start${NC}   - Start application"
echo -e "   ${BLUE}3x-ui-monitor stop${NC}    - Stop application"
echo -e "   ${BLUE}3x-ui-monitor restart${NC} - Restart application"
echo -e "   ${BLUE}3x-ui-monitor logs${NC}    - View logs"
echo -e "   ${BLUE}3x-ui-monitor update${NC}  - Update to latest version"
echo -e "   ${BLUE}3x-ui-monitor status${NC}  - Check status"
echo -e "${RED}🗑️ To uninstall: ${NC}${BLUE}bash $INSTALL_DIR/uninstall.sh${NC}"

if [ ! -z "$DOMAIN" ]; then
    echo -e "${GREEN}🔒 SSL certificate will auto-renew every 90 days${NC}"
fi
