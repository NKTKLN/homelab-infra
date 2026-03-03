# General container Parameters

variable "hostname" {
  description = "Hostname for the container"
  type        = string
}

variable "node_name" {
  description = "Proxmox node where the container will be created"
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
  description = "Proxmox storage pool for the container disk"
  type        = string
}

variable "disk_image_type" {
  description = "Type of the disk image"
  type        = string
  default     = "ubuntu"
}

variable "disk_image_id" {
  description = "ID of the disk image"
  type        = string
}

# Network Configuration

variable "network_bridge" {
  description = "Bridge to attach the container network interface to"
  type        = string
  default     = "vmbr0"
}

variable "ipaddr" {
  description = "IP address for the container in CIDR format (e.g. 192.168.1.10/24)"
  type        = string
}

variable "gateway" {
  description = "Default network gateway for the container"
  type        = string
}

variable "nameservers" {
  description = "DNS nameservers for the container"
  type        = list(string)
  default     = ["8.8.8.8"]
}

# System Configuration

variable "password" {
  description = "Default user password for the container. If null, a random password will be generated."
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key to inject"
  type        = string
}

# Firewall

variable "firewall_enable" {
  description = "Enable or disable the Proxmox firewall for the container"
  type        = bool
  default     = false
}

variable "firewall_rules" {
  description = "List of firewall rules to apply to the container"
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
