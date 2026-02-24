variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "allowed_cidr" {
  description = "CIDR block allowed to access SSH and PostgreSQL (e.g. your IP: 203.0.113.5/32)"
  type        = string
  default     = "0.0.0.0/0"
}
