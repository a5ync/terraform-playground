#!/bin/bash
sudo apt update -y
sudo apt install -y nginx certbot python3-certbot-nginx openssl ufw

# Install Ops Agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
sudo systemctl restart google-cloud-ops-agent

# Enable UFW firewall
sudo ufw allow ssh
sudo ufw allow https
sudo ufw enable -y

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Create a default web page
echo "<h1>Hello, World from Nginx with HTTPS!</h1>" | sudo tee /var/www/html/index.html

# Check if a domain is set for Let's Encrypt
DOMAIN="your-domain.com"
if [[ "$DOMAIN" != "your-domain.com" ]]; then
    # Request a real SSL certificate from Let's Encrypt
    sudo certbot --nginx -n --agree-tos --email your-email@example.com -d $DOMAIN
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
else
    # Generate a self-signed SSL certificate if no domain is available
    sudo mkdir -p /etc/nginx/ssl
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt \
      -subj "/C=US/ST=Example/L=City/O=Company/OU=IT/CN=$(hostname -I | awk '{print $1}')"
    CERT_PATH="/etc/nginx/ssl/nginx.crt"
    KEY_PATH="/etc/nginx/ssl/nginx.key"
fi

cat <<EOF | sudo tee /etc/nginx/sites-available/default
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF

# Replace placeholders in the config file with actual paths
sudo sed -i "s|/etc/nginx/ssl/nginx.crt|$CERT_PATH|g" /etc/nginx/sites-available/default
sudo sed -i "s|/etc/nginx/ssl/nginx.key|$KEY_PATH|g" /etc/nginx/sites-available/default

# Restart Nginx to apply changes
sudo systemctl restart nginx
