variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "my_ip" {
  description = "Your public IP for firewall rules"
  type        = string
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "async"
}
