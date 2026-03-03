# General VM Parameters

variable "name" {
  description = "Name of the VM"
  type        = string
}

variable "hostname" {
  description = "Hostname for the VM"
  type        = string
}

variable "node_name" {
  description = "Proxmox node where the VM will be created"
  type        = string
}

# Hardware Configuration

variable "cores" {
  description = "Number of CPU cores"
  type        = number

  validation {
    condition     = var.cores > 0
    error_message = "Number of CPU cores must be greater than 0."
  }
}

variable "memory" {
  description = "Amount of RAM in MB"
  type        = number

  validation {
    condition     = var.memory > 0
    error_message = "Memory must be greater than 0."
  }
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number

  validation {
    condition     = var.disk_size > 0
    error_message = "Disk size must be greater than 0."
  }
}

variable "disk_storage" {
  description = "Proxmox storage pool for the VM disk"
  type        = string
}

variable "disk_image_id" {
  description = "ID of the disk image"
  type        = string
}

# Network Configuration

variable "network_bridge" {
  description = "Bridge to attach the VM network interface to"
  type        = string
  default     = "vmbr0"
}

variable "ipaddr" {
  description = "IP address for the VM in CIDR format (e.g. 192.168.1.10/24)"
  type        = string
}

variable "gateway" {
  description = "Default network gateway for the VM"
  type        = string
}

variable "nameservers" {
  description = "DNS nameservers for the VM"
  type        = list(string)
  default     = ["8.8.8.8"]
}

# Cloud-init Configuration

variable "snippets_storage" {
  description = "Proxmox datastore used for Cloud-Init snippets"
  type        = string
}

variable "snippets_node_name" {
  description = "Proxmox node where the snippets datastore exists"
  type        = string
}

variable "cloud_init_template" {
  description = "Path to the Cloud-Init template file"
  type        = string
}

variable "user" {
  description = "Default user name for the VM"
  type        = string
}

variable "password" {
  description = "Default user password for the VM. If null, a random password will be generated."
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key to inject via cloud-init"
  type        = string
}

variable "timezone" {
  description = "Timezone for the VM"
  type        = string
  default     = "Europe/Moscow"
}

variable "locale" {
  description = "System locale for the VM"
  type        = string
  default     = "en_US.UTF-8"
}

# Firewall

variable "firewall_enable" {
  description = "Enable or disable the Proxmox firewall for the VM"
  type        = bool
  default     = false
}

variable "firewall_rules" {
  description = "List of firewall rules to apply to the VM"
  type = list(object({
    # Required
    action = string

    # Optional
    type    = optional(string, "in")
    proto   = optional(string)
    dport   = optional(string)
    sport   = optional(string)
    source  = optional(string)
    dest    = optional(string)
    iface   = optional(string)
    log     = optional(string)
    comment = optional(string)
    enabled = optional(bool, true)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.firewall_rules :
      contains(["ACCEPT", "DROP", "REJECT"], rule.action)
    ])
    error_message = "Each firewall rule 'action' must be one of: ACCEPT, DROP, REJECT."
  }

  validation {
    condition = alltrue([
      for rule in var.firewall_rules :
      rule.type == null || contains(["in", "out"], rule.type)
    ])
    error_message = "Each firewall rule 'type' must be one of: in, out, or null."
  }

  validation {
    condition = alltrue([
      for rule in var.firewall_rules :
      rule.log == null || contains(
        ["emerg", "alert", "crit", "err", "warning", "notice", "info", "debug", "nolog"],
        rule.log
      )
    ])
    error_message = "Each firewall rule 'log' must be one of: emerg, alert, crit, err, warning, notice, info, debug, nolog, or null."
  }
}

# VirtioFS Shared Directory

variable "virtiofs" {
  description = "List of VirtioFS shared directories for the VM"
  type = list(object({
    # Required
    name = string
    path = string

    # Optional
    comment = optional(string)
  }))
  default = []
}

# Shared PCI

variable "pci_devices" {
  description = "List of shared PCI for the VM"
  type = list(object({
    # Required
    name         = string
    path         = string
    id           = string
    subsystem_id = string

    # Optional
    comment          = optional(string)
    iommu_group      = optional(number)
    mediated_devices = optional(bool, false)
  }))
  default = []
}
