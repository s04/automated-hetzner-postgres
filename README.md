# Automated Hetzner PostgreSQL Setup

This repository provides an automated solution to set up a PostgreSQL database server on Hetzner Cloud using Terraform and Ansible. The setup includes infrastructure provisioning and configuration management for a seamless deployment experience.

## Prerequisites

Before you begin, ensure you have the following tools installed on your local machine:

- [Terraform](https://www.terraform.io/downloads.html)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [Hetzner Cloud CLI](https://github.com/hetznercloud/cli) (optional, for managing resources)

## Setup Instructions

### 1. Configure Hetzner Cloud API Token

You need to provide your Hetzner Cloud API Token for authentication. This can be done by setting the `HCLOUD_TOKEN` environment variable. The token can be found or created in your Hetzner Cloud account settings.

```bash
export HCLOUD_TOKEN=<your-token>
```

Alternatively, you can securely set the token using a Terraform variable file or another secure method. Ensure that this token has sufficient permissions to create and manage resources in your Hetzner Cloud account.

### 2. Provision Infrastructure with Terraform

Navigate to the `terraform` directory and initialize the Terraform workspace:

```bash
cd terraform
terraform init
```

To see a preview of the changes that will be made, use:

```bash
terraform plan
```

To apply the changes and provision the infrastructure, execute:

```bash
terraform apply
```

### 3. Configure the Server with Ansible

After the infrastructure has been provisioned, return to the root directory and use Ansible to configure the PostgreSQL server. Ensure the `inventory.ini` file contains the correct IP address and SSH details of the newly created server.

Run the Ansible playbook:

```bash
cd ..
ansible-playbook -i inventory.ini playbook.yaml
```

This playbook will handle the installation and configuration of PostgreSQL on the server.

## Cleanup

To destroy the infrastructure created by Terraform, navigate back to the `terraform` directory and run:

```bash
cd terraform
terraform destroy
```

This will delete all resources provisioned by Terraform.

## Notes

- Ensure that your firewall rules and security groups are configured to allow access to the PostgreSQL server as needed.
- Backup your PostgreSQL database regularly and securely store your API tokens and credentials.

## Contributing

Contributions are welcome! Please submit a pull request or open an issue to discuss changes or feature requests.