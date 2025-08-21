# rke2-cluster

This repository contains infrastructure-as-code and automation for deploying a highly available RKE2 (Rancher Kubernetes Engine 2) cluster on Proxmox using Terraform and Ansible.

## Features
- Automated VM provisioning on Proxmox with Terraform
- Cluster configuration and application deployment with Ansible
- HAProxy and Keepalived for high availability
- MetalLB for load balancer services
- Longhorn for distributed storage
- Prometheus for monitoring
- Modular roles for easy customization

## Directory Structure
- `main.tf`, `variables.tf`, `outputs.tf`, etc.: Terraform configuration files
- `ansible/`: Ansible playbooks, roles, and inventory
- `templates/`: Cloud-init and other template files
- `scripts/`: Helper scripts
- `.rendered/`: Auto-generated files (ignored by git)

## Getting Started

### Prerequisites
- Proxmox VE cluster
- Terraform
- Ansible
- Python 3

### Setup
1. **Clone the repository:**
   ```sh
   git clone https://github.com/yourusername/rke2-cluster.git
   cd rke2-cluster
   ```
2. **Configure variables:**
   - Copy and edit example files:
     ```sh
     cp terraform.tfvars.example terraform.tfvars
     cp ansible/hosts.example ansible/hosts
     cp ansible/group_vars/all.yml.example ansible/group_vars/all.yml
     cp variables.tf.example variables.tf
     ```
   - Edit these files to match your environment (do NOT commit secrets).

3. **Provision VMs with Terraform:**
   ```sh
   terraform init
   terraform apply
   ```

4. **Configure the cluster with Ansible:**
   ```sh
   cd ansible
   ansible-playbook site.yml
   ```

## Security
- Sensitive files are ignored by `.gitignore`.
- Only `.example` files are tracked for configuration.
- **Never commit real secrets or credentials.**

## License
MIT

## Contributing
Pull requests are welcome! Please open an issue first to discuss major changes.

## Authors
- Felipe Miranda <felipemiranda@outlook.com>

---

> This project is intended for educational and homelab use. Use at your own risk.
