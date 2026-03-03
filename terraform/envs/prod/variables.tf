# Proxmox API Configuration

variable "pve_api_url" {
  description = "Base URL of the Proxmox API (e.g. https://proxmox.example.com:8006/api2/json)"
  type        = string
}

variable "pve_token_id" {
  description = "Proxmox API token ID in the format user@realm!tokenname"
  type        = string
}

variable "pve_token_secret" {
  description = "Secret value of the Proxmox API token"
  type        = string
  sensitive   = true
}

variable "pve_tls_insecure" {
  description = "Whether to skip TLS certificate verification when connecting to the Proxmox API"
  type        = bool
  default     = true
}

variable "pve_ssh_username" {
  description = "SSH username used by Terraform to connect to the Proxmox host"
  type        = string
}

variable "node_name" {
  description = "Proxmox node where the VMs will be created"
  type        = string
}

variable "disk_storage" {
  description = "Proxmox storage pool to use for the VM disks"
  type        = string
}

variable "disk_image_storage" {
  description = "Proxmox storage pool for the VM images"
  type        = string
}

# Network Configuration

variable "gateway" {
  description = "Default network gateway for the VMs"
  type        = string
}

variable "nameservers" {
  description = "DNS nameservers for the VMs"
  type        = list(string)
  default     = ["8.8.8.8"]
}

# Cloud-init Settings

variable "snippets_storage" {
  description = "Proxmox datastore used for Cloud-Init snippets"
  type        = string
}

variable "snippets_node_name" {
  description = "Proxmox node where the snippets datastore exists"
  type        = string
}

variable "user" {
  description = "Default user name for the VMs"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to inject into the VMs using cloud-init"
  type        = string
}

variable "timezone" {
  description = "Timezone for the VMs"
  type        = string
  default     = "Europe/Moscow"
}

variable "locale" {
  description = "System locale for the VMs"
  type        = string
  default     = "en_US.UTF-8"
}

# VirtioFS Shared Directories

variable "virtiofs" {
  description = "List of VirtioFS shared directories for the storage VM"
  type = list(object({
    # Required
    name = string
    path = string

    # Optional
    node    = optional(string)
    comment = optional(string)
  }))
  default = []
}

# Shared PCI

variable "pci_devices" {
  description = "List of shared PCI devices for GPU worker VM"
  type = list(object({
    # Required
    name         = string
    path         = string
    id           = string
    subsystem_id = string

    # Optional
    node             = optional(string)
    comment          = optional(string)
    iommu_group      = optional(number)
    mediated_devices = optional(bool, false)
  }))
  default = []
}
