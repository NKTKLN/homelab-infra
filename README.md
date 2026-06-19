# 🏠 Homelab Infra

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Python 3.13+](https://img.shields.io/badge/Python-3.13%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?logo=opentofu&logoColor=black)](https://opentofu.org/)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Proxmox](https://img.shields.io/badge/Proxmox-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/en/proxmox-virtual-environment)
[![Task](https://img.shields.io/badge/Task-29BEB0?logo=task&logoColor=white)](https://taskfile.dev/)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-FAB040?logo=pre-commit&logoColor=black)](https://pre-commit.com/)

**homelab-infra** is an Infrastructure-as-Code repository for managing a personal homelab platform built on **Proxmox**. The project combines **Terraform / OpenTofu** for provisioning and **Ansible** for post-provision configuration.

## 📦 Dependencies

* [Python 3.13+](https://www.python.org/downloads/)
* [uv](https://docs.astral.sh/uv/)
* [Task](https://taskfile.dev/)
* [Terraform](https://developer.hashicorp.com/terraform) or [OpenTofu](https://opentofu.org/)
* [Ansible](https://www.ansible.com/)
* [Proxmox VE](https://www.proxmox.com/en/proxmox-virtual-environment)

## 🧱 Overview

The infrastructure is defined declaratively and split into two layers:

* **Terraform**
  * VM & container provisioning
  * cloud-init, networking, storage
  * PCI passthrough (GPU)
* **Ansible**
  * baseline configuration
  * k3s cluster setup
  * Docker, VPN, storage, ops tooling

## 🚀 Workflow

### Infrastructure

```bash
task tf-all      # fmt → init → validate → plan
task tf-apply    # apply changes
````

### Configuration

```bash
task ansible-deploy  # lint → check → apply
```

---

## 🔌 GPU / PCI passthrough

To attach a PCI device (e.g. GPU) in Terraform, you need:

```hcl
pci_devices = [
  {
    name         = "gpu"
    id           = "10de:1db1"
    subsystem_id = "10de:1212"
    path         = "0000:05:00.0"
    iommu_group  = 15
  }
]
```

### How to get these values

#### 1. List PCI devices

```bash
lspci -nn
```

Example:

```text
05:00.0 3D controller [0302]: NVIDIA Corporation GV100GL [Tesla V100] [10de:1db1]
```

→ `id = 10de:1db1`

#### 2. Get full device info

```bash
lspci -nnk -s 05:00.0
```

Look for:

```text
Subsystem: NVIDIA Corporation Device [10de:1212]
Kernel driver in use: vfio-pci
```

→ `subsystem_id = 10de:1212`

#### 3. Get PCI path

Usually matches:

```text
0000:05:00.0
```

→ `path = 0000:05:00.0`

#### 4. Get IOMMU group

```bash
find /sys/kernel/iommu_groups/ -type l | grep 05:00.0
```

Example:

```text
/sys/kernel/iommu_groups/15/devices/0000:05:00.0
```

→ `iommu_group = 15`

---

## 🔑 Proxmox API token (for Terraform)

Terraform uses a Proxmox API token instead of a password.

### 1. Create role and user

On Proxmox node:

```bash
pveum role add TerraformProv -privs "VM.Allocate VM.Config.* VM.PowerMgmt Datastore.AllocateSpace Datastore.AllocateTemplate Sys.Audit"

pveum user add terraform-prov@pve --password <password>

pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

### 2. Create API token

In **Proxmox Web UI**:

1. Datacenter → Permissions → API Tokens
2. Click **Add**
3. User: `terraform-prov@pve`
4. Token ID: `terraform`
5. Disable **Privilege separation** (recommended for simplicity)
6. Save and copy **Secret**

### 3. Use in Terraform

```hcl
pve_api_url      = "https://<host>:8006/api2/json"
pve_token_id     = "terraform-prov@pve!terraform"
pve_token_secret = "<secret>"
```

---

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
