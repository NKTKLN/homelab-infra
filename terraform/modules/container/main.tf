resource "proxmox_virtual_environment_container" "container" {
  # General
  node_name    = var.node_name
  # Unprivileged containers improve security and are recommended for production
  unprivileged = true

  startup {
    order      = 1
    up_delay   = 0
    down_delay = 0
  }

  # Template clone
  operating_system {
    # LXC template file downloaded via the image module
    template_file_id = var.disk_image_id
    type             = var.disk_image_type
  }

  # CPU / RAM
  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  # Disk
  disk {
    datastore_id = var.disk_storage
    size         = var.disk_size
  }

  # Network
  network_interface {
    name = var.network_bridge
  }

  # Cloud-init
  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ipaddr
        gateway = var.gateway
      }
    }

    dns {
      servers = var.nameservers
    }

    # Inject user SSH key — LXC cloud-init differs from VMs
    user_account {
      keys     = [var.ssh_public_key]
      password = local.container_password
    }
  }
}

resource "random_password" "container_password" {
  # Generate password only if the user did not provide one
  count   = var.password == null ? 1 : 0
  length  = 16
  special = true
}

locals {
  # Prefer explicit password, otherwise fallback to generated one
  container_password = var.password != null ? var.password : random_password.container_password[0].result
}

resource "proxmox_virtual_environment_firewall_options" "container_rules" {
  node_name    = proxmox_virtual_environment_container.container.node_name
  container_id = proxmox_virtual_environment_container.container.id

  # Firewall can be enabled per-container; disabled by default for flexibility
  enabled = var.firewall_enable
}

resource "proxmox_virtual_environment_firewall_rules" "container_rules" {
  node_name    = proxmox_virtual_environment_container.container.node_name
  container_id = proxmox_virtual_environment_container.container.id

  # Dynamic rule list — useful for defining per-container firewall behavior in envs/prod/main.tf
  dynamic "rule" {
    for_each = var.firewall_rules

    content {
      action  = rule.value.action
      type    = rule.value.type
      proto   = rule.value.proto
      dport   = rule.value.dport
      sport   = rule.value.sport
      source  = rule.value.source
      dest    = rule.value.dest
      iface   = rule.value.iface
      comment = rule.value.comment
      enabled = rule.value.enabled
      log     = rule.value.log
    }
  }
}
