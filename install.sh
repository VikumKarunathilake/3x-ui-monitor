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

echo -e "${YELLOW}📦 Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo -e "${GREEN}✅ Docker installed${NC}"
else
    echo -e "${GREEN}✅ Docker already installed${NC}"
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

echo -e "${YELLOW}🔨 Building and starting application...${NC}"
docker stop $APP_NAME 2>/dev/null || true
docker rm $APP_NAME 2>/dev/null || true
docker build -t $APP_NAME .
docker run -d --name $APP_NAME -p $APP_PORT:3000 --restart unless-stopped $APP_NAME

# Setup SSL if domain provided
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

case "$1" in
    start)
        docker start $APP_NAME
        echo "✅ Started $APP_NAME"
        ;;
    stop)
        docker stop $APP_NAME
        echo "🛑 Stopped $APP_NAME"
        ;;
    restart)
        docker restart $APP_NAME
        echo "🔄 Restarted $APP_NAME"
        ;;
    logs)
        docker logs -f $APP_NAME
        ;;
    update)
        cd /opt/$APP_NAME
        git pull origin main
        docker stop $APP_NAME
        docker rm $APP_NAME
        docker build -t $APP_NAME .
        docker run -d --name $APP_NAME -p 3000:3000 --restart unless-stopped $APP_NAME
        echo "🚀 Updated $APP_NAME"
        ;;
    status)
        docker ps | grep $APP_NAME || echo "❌ $APP_NAME not running"
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

if [ ! -z "$DOMAIN" ]; then
    echo -e "${GREEN}🔒 SSL certificate will auto-renew every 90 days${NC}"
fi

echo -e "${YELLOW}⚠️  Please log out and log back in to use Docker without sudo${NC}"