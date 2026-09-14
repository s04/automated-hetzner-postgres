variable "hcloud_token" {
  description = "Hetzner API token; prefer HCLOUD_TOKEN in the environment."
  type        = string
  sensitive   = true
  default     = null
}

variable "allowed_cidr" {
  description = "Trusted SSH source CIDR, typically your public IPv4 address with /32."
  type        = string
  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && !endswith(var.allowed_cidr, "/0")
    error_message = "Supply a valid restricted CIDR; unrestricted /0 access is not allowed."
  }
}

variable "server_name" {
  description = "Server name, also used to name the firewall and SSH key."
  type        = string
  default     = "postgres-server"
}

variable "server_type" {
  description = "Hetzner server type; availability varies by location."
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner datacenter location."
  type        = string
  default     = "nbg1"
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key to install on the server."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "server_backups" {
  description = "Enable paid Hetzner server backups (not a replacement for PostgreSQL dumps)."
  type        = bool
  default     = false
}
