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

## Cluster VM Specifications

The following are the recommended VM specifications for this cluster. The goal is to separate disks for ETCD, Containerd, Kubelet, and container logs, which helps distribute I/O operations and prevents disk contention. The recommended mount points for each disk are as follows:

| Purpose           | Mount Point            | Recommended Size | Applies To         |
|-------------------|-----------------------|------------------|--------------------|
| OS & root         | `/`                   | 32 GB            | Master & Worker    |
| ETCD data         | `/var/lib/etcd`       | 32 GB            | Master only        |
| Containerd data   | `/var/lib/containerd` | 64 GB            | Master & Worker    |
| Kubelet data      | `/var/lib/kubelet`    | 64 GB            | Master & Worker    |
| Container logs    | `/var/log/pods`       | 32 GB            | Master & Worker    |
| Longhorn storage  | `/var/lib/longhorn`   | 1 TB             | Worker only        |

> Adjust disk sizes as needed based on your workload requirements.



### Control Plane Nodes
- 8 vCPU
- 8 GB RAM

### Worker Nodes
- 8 vCPU
- 16 GB RAM

### Hostname/IP/Role Table

| Hostname        | IP           | Role                          |
|-----------------|--------------|-------------------------------|
| rke2-vip-lb     | 172.16.0.50  | MetalLB VIP                   |
| rke2-master1    | 172.16.0.51  | Control Plane                 |
| rke2-master2    | 172.16.0.52  | Control Plane                 |
| rke2-master3    | 172.16.0.53  | Control Plane                 |
| rke2-agent1     | 172.16.0.54  | Worker Node                   |
| rke2-agent2     | 172.16.0.55  | Worker Node                   |
| rke2-agent3     | 172.16.0.56  | Worker Node                   |
| rke2-ha1        | 172.16.0.57  | Fixed Address Registration    |
| rke2-ha2        | 172.16.0.58  | Fixed Address Registration    |
| rke2-ha-vip     | 172.16.0.59  | Fixed Address Registration VIP |

### Prerequisites
- Proxmox VE cluster
- Terraform
- Ansible
- Python 3

### Setup
1. **Clone the repository:**
   ```sh
   git clone https://github.com/FelipeMiranda/rke2-cluster.git
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
