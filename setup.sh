#!/bin/bash

# --- 1. CONFIGURATION ---
APP_NAME="usda-food-search"
APP_DIR="/home/ubuntu/$APP_NAME"
DOMAIN="yourdomain.com" # <--- UPDATE THIS
EMAIL="your@email.com"  # <--- UPDATE THIS

# --- 2. SYSTEM INSTALLATION ---
# Added 'curl' which is needed for your pip bootstrap
sudo apt update && sudo apt install -y nginx python3-venv certbot python3-certbot-nginx curl

# --- 3. PYTHON ENVIRONMENT SETUP (Merged from init.sh) ---
echo "Building Python Virtual Environment..."
cd $APP_DIR

# Create venv and install pip/dependencies
# Using your specific flags from init.sh
python3 -m venv --without-pip --copies venv
. venv/bin/activate
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py
pip install --upgrade pip
pip install "fastapi[standard]"
pip install pandas
rm get-pip.py
deactivate

# --- 4. GLOBAL NGINX SETUP (Rate Limiting) ---
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    sudo sed -i '/http {/a \    limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;' /etc/nginx/nginx.conf
fi

# --- 5. SYSTEMD DAEMONS (The Workers) ---
for PORT in 8000 8001; do
cat <<EOF | sudo tee /etc/systemd/system/api-$PORT.service
[Unit]
Description=API Instance on Port $PORT
After=network.target

[Service]
User=ubuntu
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port $PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now api-$PORT
done

# --- 6. NGINX SITE CONFIG (The Load Balancer) ---
cat <<EOF | sudo tee /etc/nginx/sites-available/$APP_NAME
upstream backend_api {
    least_conn;
    server 127.0.0.1:8000 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8001 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        limit_req zone=mylimit burst=20 nodelay;
        proxy_pass http://backend_api;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable site and disable default
sudo ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Restart Nginx to make Port 80 active for Certbot
sudo systemctl restart nginx

# --- 7. SSL WITH CERTBOT ---
# This will modify the file above to enable HTTPS
sudo certbot --nginx --non-interactive --agree-tos -m "$EMAIL" -d "$DOMAIN" -d "www.$DOMAIN"

# --- 8. NGINX AUTO-RESTART SETUP ---
sudo mkdir -p /etc/systemd/system/nginx.service.d/
cat <<EOF | sudo tee /etc/systemd/system/nginx.service.d/restart.conf
[Service]
Restart=on-failure
RestartSec=5s
EOF
sudo systemctl daemon-reload

# --- 9. PERMISSIONS FIX ---
# Ensure ubuntu user owns the environment we just built
sudo chown -R ubuntu:ubuntu $APP_DIR

echo "-----------------------------------------------"
echo "DEPLOYMENT COMPLETE!"
echo "Your API is running at https://$DOMAIN"
echo "-----------------------------------------------"
