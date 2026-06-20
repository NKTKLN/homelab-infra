# 🏠 Homelab Infra

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE.md)
[![Python 3.13+](https://img.shields.io/badge/Python-3.13%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?logo=opentofu&logoColor=black)](https://opentofu.org/)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Proxmox](https://img.shields.io/badge/Proxmox-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/en/proxmox-virtual-environment)
[![Task](https://img.shields.io/badge/Task-29BEB0?logo=task&logoColor=white)](https://taskfile.dev/)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-FAB040?logo=pre-commit&logoColor=black)](https://pre-commit.com/)

**homelab** is an Infrastructure-as-Code repository for managing a personal homelab platform built on **Proxmox**. The project combines **Terraform / OpenTofu** for provisioning and **Ansible** for post-provision configuration.

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
  * Docker, VPN, ops tooling

## ⚙️ Configuration

Before running, create the config files below. **All of them are gitignored** —
they hold secrets and are never committed.

### Terraform variables

```bash
cp terraform/envs/prod/terraform.tfvars.example terraform/envs/prod/terraform.tfvars
```

Then fill in:

* **Proxmox API** — endpoint and token → see [Proxmox API token](./docs/proxmox-api.md)
* **Node & storage** — `node_name`, `disk_storage`, `disk_image_storage`, `snippets_storage`
  (the `local` storage needs the **Snippets** content type enabled)
* **SSH key** — absolute path to your public key (`file()` does not expand `~`)
* **PCI / GPU passthrough** — `pci_devices` (or `[]` to skip) → see [GPU / PCI passthrough](./docs/pci-passthrough.md)

### AmneziaWG proxy (optional)

`vm-amnezia-proxy` runs an AmneziaWG client + SOCKS5 proxy. Export the client
config from the Amnezia app and place it at:

```text
sensitive/amnezia/awg.conf
```

> [!NOTE]
> The AmneziaWG config may need explicit route exceptions so the SOCKS5 proxy
> remains reachable from the Docker bridge and the LAN while outbound traffic is
> routed through AmneziaWG.
>
> Add the following lines to the `[Interface]` section of `sensitive/amnezia/awg.conf`:
>
> ```ini
> PostUp = ip route replace 172.18.0.0/16 dev eth0 table 51820; ip route replace 192.168.1.0/24 via 172.18.0.1 dev eth0 table 51820
> PostDown = ip route del 172.18.0.0/16 table 51820 2>/dev/null || true; ip route del 192.168.1.0/24 table 51820 2>/dev/null || true
> ```
>
> Adjust `172.18.0.0/16`, `172.18.0.1`, and `192.168.1.0/24` if the Docker
> network or LAN subnet is different.

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

## 📚 Documentation

* [Proxmox API token](./docs/proxmox-api.md) — create the token Terraform uses
* [GPU / PCI passthrough](./docs/pci-passthrough.md) — attach a GPU to the worker node

---

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE.md) file for details.
