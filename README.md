# Automated Hetzner PostgreSQL Setup

This repository provides an automated solution to set up a PostgreSQL database server on Hetzner Cloud using Terraform and Ansible. The setup includes infrastructure provisioning, a Hetzner Cloud Firewall, and configuration management for a seamless deployment experience.

## Prerequisites

Before you begin, ensure you have the following tools installed on your local machine:

- [Terraform](https://www.terraform.io/downloads.html) (>= 1.5)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [Hetzner Cloud CLI](https://github.com/hetznercloud/cli) (optional, for managing resources)

## Setup Instructions

### 1. Configure Variables

Copy the example variables file and fill in your values:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your Hetzner Cloud API token and allowed CIDR:

```hcl
hcloud_token = "your-actual-token"
allowed_cidr = "203.0.113.5/32"  # Your public IP
```

> **Important:** Never commit `terraform.tfvars` — it is already in `.gitignore`.

### 2. Provision Infrastructure with Terraform

Initialize the Terraform workspace:

```bash
cd terraform
terraform init
```

Preview the changes:

```bash
terraform plan
```

Apply the changes:

```bash
terraform apply
```

This creates the server **and** a Hetzner Cloud Firewall that restricts SSH (22) and PostgreSQL (54321) access to the CIDR you specified.

### 3. Configure the Server with Ansible

Set the required environment variables for PostgreSQL:

```bash
export POSTGRES_DB=mydb
export POSTGRES_USER=myuser
export POSTGRES_PASSWORD=mysecretpassword
```

Update `inventory.ini` with the server IP from Terraform output, then run:

```bash
ansible-playbook -i inventory.ini playbook.yaml
```

### 4. Connect to PostgreSQL

Since PostgreSQL binds to `127.0.0.1`, use an SSH tunnel to connect:

```bash
ssh -L 54321:127.0.0.1:54321 root@<server-ip>
```

Then connect from your local machine:

```bash
psql -h 127.0.0.1 -p 54321 -U myuser -d mydb
```

## Security

### Docker and UFW

Docker manipulates iptables directly, which means ports published by Docker containers bypass UFW rules entirely. This is a [well-known issue](https://github.com/moby/moby/issues/4737).

This setup mitigates the problem two ways:

1. **Hetzner Cloud Firewall** — applied at the hypervisor level, outside the VM. Only `allowed_cidr` can reach ports 22 and 54321. This is the real perimeter.
2. **Bind to 127.0.0.1** — the PostgreSQL container only listens on localhost, so even if the Hetzner firewall were misconfigured, the port is not reachable from the internet. Use an SSH tunnel to connect.

### Other Hardening

- SSH password authentication is disabled (key-only)
- fail2ban is installed and enabled
- UFW is configured as defense in depth (deny by default, allow 22 + 54321)
- PostgreSQL uses `scram-sha-256` authentication (not md5)

## Cleanup

To destroy the infrastructure:

```bash
cd terraform
terraform destroy
```

## Contributing

Contributions are welcome! Please submit a pull request or open an issue to discuss changes or feature requests.
