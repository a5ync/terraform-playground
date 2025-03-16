terraform {
  backend "gcs" {
    bucket = "terraform-state-smart-howl" # Must match the GCS bucket name
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_service_account" "ops_agent_sa" {
  project      = var.project_id
  account_id   = "ops-agent-sa"
  display_name = "Ops Agent Service Account"
}

resource "google_project_iam_member" "ops_agent_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.ops_agent_sa.email}"
}

resource "google_project_iam_member" "ops_agent_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.ops_agent_sa.email}"
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
    access_config {} # Assigns a public IP automatically
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file("~/.ssh/id_ap8.pub")}"
  }

  metadata_startup_script = file("${path.module}/scripts/startup.sh")

  tags = ["https-server"]
  service_account {
    email = google_service_account.ops_agent_sa.email
    scopes = [
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/logging.write"
    ]
  }
}

# Allow HTTPS (443) only from your IP
resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [var.my_ip] # Only your IP
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
  value       = "ssh -i ~/.ssh/id_ap8 ${var.ssh_user}@${google_compute_instance.nginx_vm.network_interface[0].access_config[0].nat_ip}"
}

output "https_url" {
  description = "URL to access the Nginx server"
  value       = "https://${google_compute_instance.nginx_vm.network_interface[0].access_config[0].nat_ip}"
}
