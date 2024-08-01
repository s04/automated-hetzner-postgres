# main.tf

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

provider "hcloud" {
  token = "YOUR_API_TOKEN"
}

resource "hcloud_server" "postgres_server" {
  name        = "postgres-server"
  image       = "ubuntu-24.04"
  server_type = "cx22"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.ssh-key.id]

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