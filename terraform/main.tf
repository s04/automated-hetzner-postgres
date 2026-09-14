terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.60"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_firewall" "postgres" {
  name = "${var.server_name}-firewall"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.allowed_cidr]
  }
}

resource "hcloud_server" "postgres_server" {
  name         = var.server_name
  image        = "ubuntu-24.04"
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.ssh-key.id]
  firewall_ids = [hcloud_firewall.postgres.id]

  backups = var.server_backups

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

resource "hcloud_ssh_key" "ssh-key" {
  name       = "${var.server_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

output "server_ip" {
  value = hcloud_server.postgres_server.ipv4_address
}

output "ansible_inventory" {
  description = "Inventory consumed by scripts/inventory.py."
  value = {
    postgres_servers = {
      hosts = [hcloud_server.postgres_server.ipv4_address]
      vars  = { ansible_user = "root" }
    }
  }
}
