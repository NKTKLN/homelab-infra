resource "proxmox_virtual_environment_vm" "vm" {
  # General
  name      = var.name
  node_name = var.node_name

  # Using Q35 with viommu ensures compatibility with PCI passthrough and modern guest OSes
  machine = "q35,viommu=virtio"

  startup {
    # Ensure VM starts early in boot order (useful for cluster dependencies)
    order      = 1
    up_delay   = 0
    down_delay = 0
  }

  agent {
    # Enable QEMU guest agent to allow Terraform to retrieve IP and manage OS-level features
    enabled = true
    timeout = "5m"
  }

  # CPU / RAM
  cpu {
    sockets = 1
    cores   = var.cores
  }

  memory {
    dedicated = var.memory
  }

  # Disks
  disk {
    datastore_id = var.disk_storage
    # import_from pulls an existing qcow2 image into Proxmox storage
    # Typically used together with cloud-init images
    import_from  = var.disk_image_id
    size         = var.disk_size
    interface    = "scsi0"
  }

  dynamic "virtiofs" {
    for_each = proxmox_virtual_environment_hardware_mapping_dir.shared_dir

    # Each defined virtiofs mapping becomes a VirtioFS mount inside the VM
    # Requires Proxmox node-level hardware mapping configuration
    content {
      mapping   = virtiofs.key
      cache     = "always"
      direct_io = true
    }
  }

  # PCI passthrough
  dynamic "hostpci" {
    for_each = proxmox_virtual_environment_hardware_mapping_pci.shared_pci

    # PCI device passthrough. Each mapping refers to Proxmox hardware mapping
    # Careful: wrong mapping or IOMMU config will prevent VM startup
    content {
      device  = "hostpci${hostpci.key}"
      mapping = hostpci.value.name
      pcie    = true
    }
  }

  # Network
  network_device {
    bridge = var.network_bridge
    # Using virtio network interface for better performance on Linux guests
    model  = "virtio"
  }

  # Cloud-init
  initialization {
    # Cloud-init user-data file generated via proxmox_virtual_environment_file
    user_data_file_id = proxmox_virtual_environment_file.vm_cloud_init.id

    ip_config {
      ipv4 {
        address = var.ipaddr
        gateway = var.gateway
      }
    }

    dns {
      servers = var.nameservers
    }
  }
}

resource "proxmox_virtual_environment_file" "vm_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.snippets_node_name

  # Storing Cloud-Init user-data inside Proxmox "snippets" storage
  # Required for VMs that use initialization.user_data_file_id
  source_raw {
    # Password is passed as a bcrypt hash — never store plaintext in templates
    data = templatefile("${path.module}/templates/${var.cloud_init_template}", {
      hostname       = var.hostname
      user           = var.user
      password_hash  = bcrypt(local.vm_password)
      ssh_public_key = var.ssh_public_key
      timezone       = var.timezone
      locale         = var.locale
    })

    file_name = "${var.name}-user-data.yaml"
  }
}

resource "random_password" "vm_password" {
  # Generate password only if the user did not provide one
  count   = var.password == null ? 1 : 0
  length  = 16
  special = true
}

locals {
  # Prefer explicit password, otherwise fallback to generated one
  vm_password = var.password != null ? var.password : random_password.vm_password[0].result
}

resource "proxmox_virtual_environment_hardware_mapping_dir" "shared_dir" {
  # Creates hardware-mapping entries on the Proxmox node for VirtioFS
  for_each = { for v in var.virtiofs : v.name => v }

  name = each.key

  map = [{
    node    = var.node_name
    path    = each.value.path
    comment = try(each.value.comment, null)
  }]
}

resource "proxmox_virtual_environment_hardware_mapping_pci" "shared_pci" {
  # Persistent hardware PCI mapping to ensure stable passthrough between reboots
  for_each = { for idx, v in var.pci_devices : idx => v }

  name = each.value.name

  map = [{
    node         = var.node_name
    path         = each.value.path
    id           = each.value.id
    subsystem_id = each.value.subsystem_id
    iommu_group  = try(each.value.iommu_group, null)
    comment      = try(each.value.comment, null)
  }]

  mediated_devices = try(each.value.mediated_devices, false)
}

resource "proxmox_virtual_environment_firewall_options" "vm_rules" {
  node_name = proxmox_virtual_environment_vm.vm.node_name
  vm_id     = proxmox_virtual_environment_vm.vm.vm_id

  # Firewall can be enabled per-VM; disabled by default for flexibility
  enabled = var.firewall_enable
}

resource "proxmox_virtual_environment_firewall_rules" "vm_rules" {
  node_name = proxmox_virtual_environment_vm.vm.node_name
  vm_id     = proxmox_virtual_environment_vm.vm.vm_id

  # Dynamic rule list — useful for defining per-VM firewall behavior in envs/prod/main.tf
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
