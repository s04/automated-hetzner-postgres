# main.tf

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
  name = "postgres-firewall"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.allowed_cidr]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "54321"
    source_ips = [var.allowed_cidr]
  }
}

resource "hcloud_server" "postgres_server" {
  name        = "postgres-server"
  image       = "ubuntu-24.04"
  server_type = "cx22"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.ssh-key.id]
  firewall_ids = [hcloud_firewall.postgres.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

resource "hcloud_ssh_key" "ssh-key" {
  name       = "ssh-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

output "server_ip" {
  value = hcloud_server.postgres_server.ipv4_address
}
