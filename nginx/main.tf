terraform {
  backend "gcs" {
    bucket = "terraform-state-smart-howl"  # Must match the GCS bucket name
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_instance" "nginx_vm" {
  name         = "nginx-server"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {}  # Assigns a public IP automatically
  }

  metadata = {
    ssh-keys = "async:${file("~/.ssh/id_ap8.pub")}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y nginx certbot python3-certbot-nginx openssl ufw

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

    # Configure Nginx for HTTPS and force redirect from HTTP to HTTPS
    sudo bash -c "cat > /etc/nginx/sites-available/default" <<EOF2
    server {
        listen 80;
        server_name _;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl;
        listen [::]:443 ssl;
        server_name _;

        ssl_certificate $CERT_PATH;
        ssl_certificate_key $KEY_PATH;

        location / {
            root /var/www/html;
            index index.html;
        }
    }
    EOF2

    # Restart Nginx to apply changes
    sudo systemctl restart nginx
  EOF

  tags = ["https-server"]
}

# Allow HTTPS (443) only from your IP
resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [var.my_ip]  # Only your IP
  target_tags   = ["https-server"]
}

# Allow SSH (22) only from your IP
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.my_ip]
  target_tags   = ["https-server"]
}

# Output values for easy access
output "instance_public_ip" {
  description = "Public IP of the Nginx server"
  value       = google_compute_instance.nginx_vm.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/id_ap8 async@${google_compute_instance.nginx_vm.network_interface[0].access_config[0].nat_ip}"
}

output "https_url" {
  description = "URL to access the Nginx server"
  value       = "https://${google_compute_instance.nginx_vm.network_interface[0].access_config[0].nat_ip}"
}
