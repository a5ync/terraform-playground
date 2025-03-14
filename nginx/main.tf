terraform {
  backend "gcs" {
    bucket = "terraform-state-smart-howl"  # Must match the BUCKET_NAME
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "smart-howl-445502-u5"
  region  = "us-west1"
}

resource "google_compute_instance" "nginx_vm" {
  name         = "nginx-server"
  machine_type = "e2-micro"
  zone         = "us-west1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {}  # Assigns a public IP
  }

  metadata = {
    ssh-keys = "async:${file("~/.ssh/id_ap8.pub")}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y nginx certbot python3-certbot-nginx ufw

    # Enable UFW firewall
    sudo ufw allow ssh
    sudo ufw allow https
    sudo ufw enable -y

    # Start Nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx

    # Generate a test web page
    echo "<h1>Hello, World from Nginx with HTTPS!</h1>" | sudo tee /var/www/html/index.html

    # Obtain and configure SSL certificate from Let's Encrypt
    sudo certbot --nginx -n --agree-tos --email your-email@example.com -d your-domain.com

    # Ensure SSL auto-renewal
    echo "0 0 * * 0 root certbot renew --quiet" | sudo tee -a /etc/crontab

    # Remove HTTP (port 80) by redirecting to HTTPS
    sudo sed -i 's/listen 80;/listen 80; return 301 https:\/\/$host$request_uri;/' /etc/nginx/sites-enabled/default

    sudo systemctl restart nginx
  EOF

  tags = ["https-server"]
}

# Allow SSH (22) only from your IP
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["72.235.8.26/32"]  # Only your IP
  target_tags   = ["https-server"]
}

# Allow HTTPS (443) only from your IP
resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["72.235.8.26/32"]  # Only your IP
  target_tags   = ["https-server"]
}
