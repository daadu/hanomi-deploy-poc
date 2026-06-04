#!/usr/bin/env bash 
######
## Bootstrap VM for frontend service
##
## - The script should be executed by non-root user with sudo access (service account)
## - Doesn't cover creating this service account user for it, as well as setting up ssh access for it.
#####
set -euo pipefail

# configuration
SERVICE_USER="hanomi"
SERVICE_NAME="frontend"
SERVICE_FULL_NAME="hanomi-$SERVICE_NAME"
SERVICE_DIR="/home/$SERVICE_USER/hanomi/$SERVICE_NAME"
NODE_VERSION="20"

# Validate
if [ "$(id -un)" != "$SERVICE_USER" ]; then
    echo "ERROR: This script must be run as '$SERVICE_USER'"
    exit 1
fi

# Install & configure dependencies
echo "Installing dependencies...."
sudo apt update -y
# -- install utilities
sudo apt install -y curl wget git
# -- install nginx
sudo apt install -y nginx ufw
# -- install node via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm install $NODE_VERSION
nvm use $NODE_VERSION
NODE_PATH="$(nvm which "$NODE_VERSION")"
# -- configure ufw (if present)
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow "Nginx Full"
    sudo ufw allow OpenSSH
    sudo ufw --force enable
fi


# service setup
echo "Setting up service directory..."
# -- make service directory
mkdir -p "$SERVICE_DIR"
# -- make sub directories
mkdir -p "$SERVICE_DIR/releases"
mkdir -p "$SERVICE_DIR/config"
mkdir -p "$SERVICE_DIR/scripts"
# -- touch required files
touch "$SERVICE_DIR/config/.env"
# --- allow other users (nginx as www-data for serving static files) to traverse directories
chmod o+x /home/$SERVICE_USER
chmod o+x "$SERVICE_DIR"
chmod o+x "$SERVICE_DIR/releases"
# --- set proper permissions for config files
chmod 700 "$SERVICE_DIR/config"
chmod 600 "$SERVICE_DIR/config/.env"

# configure systemd service
echo "Configuring systemd service..."
sudo tee /etc/systemd/system/$SERVICE_FULL_NAME.service > /dev/null <<EOF
[Unit]
Description=Hanomi Frontend
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$SERVICE_DIR/releases/current
EnvironmentFile=$SERVICE_DIR/config/.env

Environment=PORT=3000
ExecStart=$NODE_PATH server.js 

# restart service if it crashes or exits unexpectedly (pm2 like behavior)
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_FULL_NAME"
# not start it yet, will be done after first deployment


# configure nginx
echo "Removing default nginx configuration..."
sudo rm -f /etc/nginx/sites-enabled/default
echo "Configuring nginx as reverse proxy for $SERVICE_FULL_NAME..."
sudo tee /etc/nginx/sites-available/$SERVICE_FULL_NAME > /dev/null <<EOF
server {
    listen 80;
    server_name _; # assuming domain + SSL terminated at load balancer / cloudflare

    gzip on;
    gzip_proxied any;
    gzip_types application/javascript application/x-javascript text/css text/javascript;
    gzip_comp_level 5;
    gzip_buffers 16 8k;
    gzip_min_length 256;

    location /_next/static/ {
            alias $SERVICE_DIR/releases/current/.next/static/;
            expires 365d;
            access_log off;
    }
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/$SERVICE_FULL_NAME /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx


echo "===== Bootstraping completed successfully ====="