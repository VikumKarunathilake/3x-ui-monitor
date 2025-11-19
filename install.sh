#!/bin/bash

set -e  # Exit on any error

echo "=============================================="
echo "   Next.js Advanced Deployment Installer"
echo "   One-Line Install Compatible"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root (don't use sudo)"
   print_info "The script will ask for sudo password when needed"
   exit 1
fi

# ------------------------------------------
# CONFIGURATION
# ------------------------------------------
echo "=== Configuration ==="
echo ""

# Check for non-interactive mode
if [[ -n "$CI" || ! -t 0 ]]; then
  print_warning "Non-interactive mode detected. Using default values."
  PORT=3000
  DOMAIN="localhost"
  REPO_URL="https://github.com/VikumKarunathilake/3x-ui-monitor"
  BRANCH="master"
  USE_DOCKER="n"
  SSL="n"
  SETUP_BACKUPS="y"
  INSTALL_MONITORING="y"
  SKIP_CONFIRM="y"
else
  read -p "Enter the port for your Next.js app (default 3000): " PORT
  PORT=${PORT:-3000}

  read -p "Enter your domain name (e.g., example.com, or 'localhost' for local): " DOMAIN
  DOMAIN=${DOMAIN:-localhost}

  read -p "Enter your GitHub repository URL (default: VikumKarunathilake/3x-ui-monitor): " REPO_URL
  REPO_URL=${REPO_URL:-"https://github.com/VikumKarunathilake/3x-ui-monitor"}

  read -p "Enter branch to deploy (default master): " BRANCH
  BRANCH=${BRANCH:-"master"}

  read -p "Install with Docker? (y/n, default n): " USE_DOCKER
  USE_DOCKER=${USE_DOCKER:-"n"}

  if [[ "$DOMAIN" != "localhost" ]]; then
    read -p "Enable SSL with Certbot? (y/n): " SSL
  else
    SSL="n"
  fi

  read -p "Setup automatic backups? (y/n, default y): " SETUP_BACKUPS
  SETUP_BACKUPS=${SETUP_BACKUPS:-"y"}

  read -p "Install monitoring tools? (y/n, default y): " INSTALL_MONITORING
  INSTALL_MONITORING=${INSTALL_MONITORING:-"y"}

  echo ""
  echo "=== Summary ==="
  echo "Port:         $PORT"
  echo "Domain:       $DOMAIN"
  echo "Repository:   $REPO_URL"
  echo "Branch:       $BRANCH"
  echo "Use Docker:   $USE_DOCKER"
  echo "SSL:          $SSL"
  echo "Backups:      $SETUP_BACKUPS"
  echo "Monitoring:   $INSTALL_MONITORING"
  echo "=============================================="
  echo ""

  read -p "Proceed with installation? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Installation cancelled."
    exit 0
  fi
fi

echo ""
print_info "Starting installation..."
sleep 2

# ------------------------------------------
# SYSTEM UPDATES
# ------------------------------------------
print_info "Updating system packages..."
sudo apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo apt install -y curl wget git build-essential software-properties-common

# ------------------------------------------
# INSTALL NGINX
# ------------------------------------------
if ! command -v nginx >/dev/null 2>&1; then
  print_info "Installing Nginx..."
  sudo apt install -y nginx
  sudo systemctl enable nginx
  sudo systemctl start nginx
  print_success "Nginx installed"
else
  print_success "Nginx already installed"
fi

# ------------------------------------------
# DOCKER INSTALLATION (OPTIONAL)
# ------------------------------------------
if [[ "$USE_DOCKER" == "y" || "$USE_DOCKER" == "Y" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    print_info "Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker $USER
    rm /tmp/get-docker.sh
    
    # Install Docker Compose
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    print_success "Docker installed"
    print_warning "You may need to log out and back in for Docker group permissions"
  else
    print_success "Docker already installed"
  fi
fi

# ------------------------------------------
# NODE.JS INSTALLATION
# ------------------------------------------
if [[ "$USE_DOCKER" != "y" && "$USE_DOCKER" != "Y" ]]; then
  if ! command -v node >/dev/null 2>&1; then
    print_info "Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    print_success "Node.js installed: $(node --version)"
  else
    print_success "Node.js already installed: $(node --version)"
  fi

  # Install pnpm
  if ! command -v pnpm >/dev/null 2>&1; then
    print_info "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    print_success "pnpm installed"
  else
    print_success "pnpm already installed"
  fi

  # Install PM2
  if ! command -v pm2 >/dev/null 2>&1; then
    print_info "Installing PM2..."
    sudo npm install -g pm2
    pm2 startup systemd -u $USER --hp $HOME | grep -v "PM2" | bash || true
    print_success "PM2 installed"
  else
    print_success "PM2 already installed"
  fi
fi

# ------------------------------------------
# CLONE REPOSITORY
# ------------------------------------------
APP_DIR="/var/www/nextapp"
print_info "Setting up application directory..."

sudo mkdir -p $APP_DIR
sudo chown -R $USER:$USER $APP_DIR

if [ -d "$APP_DIR/.git" ]; then
  print_info "Repository exists. Pulling latest changes..."
  cd $APP_DIR
  git fetch origin
  git checkout $BRANCH || git checkout -b $BRANCH origin/$BRANCH
  git pull origin $BRANCH
else
  print_info "Cloning repository..."
  sudo rm -rf $APP_DIR/*
  git clone -b $BRANCH $REPO_URL $APP_DIR
  cd $APP_DIR
fi

print_success "Repository ready"

# ------------------------------------------
# BUILD APPLICATION
# ------------------------------------------
if [[ "$USE_DOCKER" == "y" || "$USE_DOCKER" == "Y" ]]; then
  print_info "Building Docker image..."
  
  # Create Dockerfile if it doesn't exist
  if [ ! -f "Dockerfile" ]; then
    cat > Dockerfile <<'DOCKERFILE'
FROM node:20-alpine AS base
RUN apk add --no-cache libc6-compat
WORKDIR /app

FROM base AS deps
COPY package*.json pnpm-lock.yaml* ./
RUN corepack enable pnpm && pnpm install --frozen-lockfile

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN corepack enable pnpm && pnpm build

FROM base AS runner
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
DOCKERFILE
  fi

  # Create docker-compose.yml
  cat > docker-compose.yml <<DOCKERCOMPOSE
version: '3.8'

services:
  nextapp:
    build: .
    container_name: nextapp
    restart: unless-stopped
    ports:
      - "${PORT}:3000"
    environment:
      - NODE_ENV=production
    networks:
      - nextapp-network

networks:
  nextapp-network:
    driver: bridge
DOCKERCOMPOSE

  docker-compose build
  docker-compose up -d
  
  print_success "Application running in Docker"
else
  print_info "Installing dependencies and building..."
  
  # Detect package manager
  if [ -f "pnpm-lock.yaml" ]; then
    if command -v pnpm >/dev/null 2>&1; then
      pnpm install --frozen-lockfile || pnpm install
      pnpm build
    else
      npm ci || npm install
      npm run build
    fi
  elif [ -f "package-lock.json" ]; then
    npm ci || npm install
    npm run build
  else
    npm install
    npm run build
  fi

  # Start with PM2
  print_info "Starting application with PM2..."
  pm2 delete nextapp 2>/dev/null || true
  
  if [ -f "pnpm-lock.yaml" ] && command -v pnpm >/dev/null 2>&1; then
    PORT=$PORT pm2 start "pnpm start" --name nextapp
  else
    PORT=$PORT pm2 start "npm start" --name nextapp
  fi
  
  pm2 save
  print_success "Application started with PM2"
fi

# ------------------------------------------
# NGINX CONFIGURATION
# ------------------------------------------
print_info "Configuring Nginx..."

NGINX_FILE="/etc/nginx/sites-available/nextapp"

sudo bash -c "cat > $NGINX_FILE" <<NGINXCONF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Static files caching
    location /_next/static/ {
        proxy_pass http://localhost:$PORT;
        proxy_cache_valid 200 365d;
        add_header Cache-Control "public, immutable";
    }

    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://localhost:$PORT/api/health;
    }
}
NGINXCONF

sudo ln -sf $NGINX_FILE /etc/nginx/sites-enabled/nextapp
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
if sudo nginx -t; then
  sudo systemctl reload nginx
  print_success "Nginx configured"
else
  print_error "Nginx configuration error!"
  exit 1
fi

# ------------------------------------------
# SSL SETUP
# ------------------------------------------
if [[ "$SSL" == "y" || "$SSL" == "Y" ]]; then
  print_info "Installing Certbot and setting up SSL..."
  
  sudo apt install -y certbot python3-certbot-nginx
  
  # Get certificate
  sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --register-unsafely-without-email --redirect || {
    print_warning "SSL setup failed. You may need to configure DNS first."
    print_info "Run this manually later: sudo certbot --nginx -d $DOMAIN"
  }
  
  # Setup auto-renewal
  sudo systemctl enable certbot.timer 2>/dev/null || true
  sudo systemctl start certbot.timer 2>/dev/null || true
  
  print_success "SSL configured (if DNS was ready)"
fi

# ------------------------------------------
# FIREWALL SETUP
# ------------------------------------------
print_info "Configuring firewall..."

if command -v ufw >/dev/null 2>&1; then
  sudo ufw --force enable
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw reload
  print_success "Firewall configured"
fi

# ------------------------------------------
# BACKUP SETUP
# ------------------------------------------
if [[ "$SETUP_BACKUPS" == "y" || "$SETUP_BACKUPS" == "Y" ]]; then
  print_info "Setting up automated backups..."
  
  BACKUP_DIR="/var/backups/nextapp"
  sudo mkdir -p $BACKUP_DIR
  sudo chown $USER:$USER $BACKUP_DIR
  
  # Create backup script
  sudo bash -c "cat > /usr/local/bin/backup-nextapp.sh" <<'BACKUPSCRIPT'
#!/bin/bash
BACKUP_DIR="/var/backups/nextapp"
APP_DIR="/var/www/nextapp"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/nextapp_backup_$DATE.tar.gz"

# Create backup
tar -czf $BACKUP_FILE -C $(dirname $APP_DIR) $(basename $APP_DIR) 2>/dev/null

# Keep only last 7 backups
ls -t $BACKUP_DIR/nextapp_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo "$(date): Backup completed: $BACKUP_FILE"
BACKUPSCRIPT

  sudo chmod +x /usr/local/bin/backup-nextapp.sh
  
  # Add to crontab (daily at 2 AM)
  (crontab -l 2>/dev/null | grep -v "backup-nextapp"; echo "0 2 * * * /usr/local/bin/backup-nextapp.sh >> /var/log/nextapp-backup.log 2>&1") | crontab -
  
  print_success "Daily backups configured (2 AM)"
fi

# ------------------------------------------
# MONITORING SETUP
# ------------------------------------------
if [[ "$INSTALL_MONITORING" == "y" || "$INSTALL_MONITORING" == "Y" ]]; then
  print_info "Installing monitoring tools..."
  
  # Install htop for process monitoring
  sudo apt install -y htop
  
  # Setup PM2 monitoring (if not using Docker)
  if [[ "$USE_DOCKER" != "y" && "$USE_DOCKER" != "Y" ]]; then
    pm2 install pm2-logrotate 2>/dev/null || true
    pm2 set pm2-logrotate:max_size 10M 2>/dev/null || true
    pm2 set pm2-logrotate:retain 7 2>/dev/null || true
  fi
  
  print_success "Monitoring tools installed"
fi

# ------------------------------------------
# CREATE HELPER SCRIPTS
# ------------------------------------------
print_info "Creating helper scripts..."

# Create deployment script
cat > $HOME/deploy-nextapp.sh <<'DEPLOYSCRIPT'
#!/bin/bash
echo "🚀 Deploying Next.js App..."
cd /var/www/nextapp
git pull
if command -v pnpm >/dev/null 2>&1 && [ -f "pnpm-lock.yaml" ]; then
  pnpm install
  pnpm build
else
  npm ci || npm install
  npm run build
fi
pm2 restart nextapp
echo "✅ Deployment completed!"
DEPLOYSCRIPT
chmod +x $HOME/deploy-nextapp.sh

# Create logs viewer script
cat > $HOME/view-logs.sh <<'LOGSSCRIPT'
#!/bin/bash
pm2 logs nextapp --lines 100
LOGSSCRIPT
chmod +x $HOME/view-logs.sh

# Create status checker script
cat > $HOME/check-status.sh <<'STATUSSCRIPT'
#!/bin/bash
echo "=== PM2 Status ==="
pm2 status

echo ""
echo "=== Nginx Status ==="
sudo systemctl status nginx --no-pager | head -20

echo ""
echo "=== Disk Usage ==="
df -h / | grep -v "tmpfs"

echo ""
echo "=== Memory Usage ==="
free -h

echo ""
echo "=== Application Health ==="
curl -s http://localhost:3000 > /dev/null && echo "✅ App is responding" || echo "❌ App is not responding"
STATUSSCRIPT
chmod +x $HOME/check-status.sh

print_success "Helper scripts created"

# ------------------------------------------
# FINAL HEALTH CHECK
# ------------------------------------------
print_info "Performing health check..."
sleep 5

HEALTH_CHECK_PASSED=false
for i in {1..10}; do
  if curl -f http://localhost:$PORT > /dev/null 2>&1; then
    print_success "Application is responding on port $PORT"
    HEALTH_CHECK_PASSED=true
    break
  fi
  sleep 2
done

if [ "$HEALTH_CHECK_PASSED" = false ]; then
  print_warning "Application may not be responding yet."
  if [[ "$USE_DOCKER" != "y" && "$USE_DOCKER" != "Y" ]]; then
    print_info "Check logs with: pm2 logs nextapp"
  else
    print_info "Check logs with: docker-compose logs -f"
  fi
fi

# ------------------------------------------
# COMPLETION
# ------------------------------------------
echo ""
echo "=============================================="
print_success "Installation Complete!"
echo "=============================================="
echo ""
echo "📍 Application Details:"
echo "   Directory:  $APP_DIR"
echo "   Port:       $PORT"
echo "   Domain:     http://$DOMAIN"
[[ "$SSL" == "y" || "$SSL" == "Y" ]] && echo "   SSL:        https://$DOMAIN"
echo ""
echo "🛠️  Helper Commands:"
echo "   Deploy:     ~/deploy-nextapp.sh"
echo "   Logs:       ~/view-logs.sh"
echo "   Status:     ~/check-status.sh"
[[ "$USE_DOCKER" != "y" && "$USE_DOCKER" != "Y" ]] && echo "   PM2 logs:   pm2 logs nextapp"
[[ "$USE_DOCKER" != "y" && "$USE_DOCKER" != "Y" ]] && echo "   PM2 monit:  pm2 monit"
[[ "$USE_DOCKER" == "y" || "$USE_DOCKER" == "Y" ]] && echo "   Docker:     cd $APP_DIR && docker-compose logs -f"
echo ""
echo "🚀 Quick Start:"
echo "   Visit: http://$DOMAIN"
[[ "$DOMAIN" == "localhost" ]] && echo "   Or: http://YOUR_SERVER_IP:$PORT"
echo ""
echo "📚 Next Steps:"
[[ "$SSL" == "y" || "$SSL" == "Y" ]] && echo "   ✓ SSL certificate will auto-renew"
[[ "$SETUP_BACKUPS" == "y" || "$SETUP_BACKUPS" == "Y" ]] && echo "   ✓ Daily backups scheduled at 2 AM"
echo "   • Setup GitHub Actions for CI/CD"
echo "   • Configure environment variables in: $APP_DIR/.env"
echo "   • Monitor application: ~/check-status.sh"
echo ""
echo "🔐 Security Recommendations:"
echo "   • Change SSH port: sudo nano /etc/ssh/sshd_config"
echo "   • Install fail2ban: sudo apt install fail2ban"
echo "   • Regular updates: sudo apt update && sudo apt upgrade"
echo "   • Monitor logs: tail -f /var/log/nginx/access.log"
echo ""
echo "=============================================="
print_success "Happy Deploying! 🚀"
echo "=============================================="
echo ""
echo "💡 One-line install command for future use:"
echo "   bash <(curl -Ls https://raw.githubusercontent.com/VikumKarunathilake/3x-ui-monitor/master/install.sh)"
echo ""