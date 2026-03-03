module "ubuntu_image" {
  # Download KVM cloud image for VM provisioning
  source = "../../modules/image"

  disk_image_storage = var.disk_image_storage
  node_name          = var.node_name

  image_url       = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  image_file_name = "ubuntu-24.04-server-cloudimg-amd64.qcow2"
  content_type    = "import"
}

module "ubuntu_lxc_image" {
  # Download LXC template for containers
  source = "../../modules/image"

  disk_image_storage = var.disk_image_storage
  node_name          = var.node_name

  image_url       = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  image_file_name = "ubuntu-24.04-lxc.tar.zst"
  content_type    = "vztmpl"
}

locals {
  vm_definitions = {
    "vm-sandbox" = {
      hostname        = "vm-sandbox"
      cores           = 2
      memory          = 2048
      disk_size       = 20
      ipaddr          = "192.168.1.12/24"
      virtiofs        = []
      pci_devices     = []
      firewall_enable = false
      firewall_rules  = []
    }

    "vm-ops-node" = {
      hostname        = "vm-ops-node"
      cores           = 2
      memory          = 3072
      disk_size       = 20
      ipaddr          = "192.168.1.13/24"
      virtiofs        = []
      pci_devices     = []
      firewall_enable = true
      firewall_rules = [
        {
          action  = "ACCEPT"
          type    = "in"
          proto   = "tcp"
          dport   = "22"
          comment = "Allow SSH"
        },
        {
          action  = "ACCEPT"
          type    = "in"
          proto   = "tcp"
          dport   = "9100"
          comment = "Allow Node Exporter"
        },
        {
          action  = "DROP"
          type    = "in"
          comment = "Drop all other incoming traffic"
        }
      ]
    }

    "vm-storage-node" = {
      hostname        = "vm-storage-node"
      cores           = 2
      memory          = 4096
      disk_size       = 32
      ipaddr          = "192.168.1.14/24"
      virtiofs        = var.virtiofs
      pci_devices     = []
      firewall_enable = false
      firewall_rules  = []
    }

    "vm-k8s-master-1" = {
      hostname        = "vm-k8s-master-1"
      cores           = 4
      memory          = 6144
      disk_size       = 40
      ipaddr          = "192.168.1.15/24"
      virtiofs        = []
      pci_devices     = []
      firewall_enable = false
      firewall_rules  = []
    }

    "vm-k8s-worker-1" = {
      hostname        = "vm-k8s-worker-1"
      cores           = 4
      memory          = 6144
      disk_size       = 40
      ipaddr          = "192.168.1.16/24"
      virtiofs        = []
      pci_devices     = []
      firewall_enable = false
      firewall_rules  = []
    }

    "vm-k8s-gpu-worker-1" = {
      hostname        = "vm-k8s-gpu-worker-1"
      cores           = 4
      memory          = 8192
      disk_size       = 60
      ipaddr          = "192.168.1.17/24"
      virtiofs        = []
      pci_devices     = var.pci_devices
      firewall_enable = false
      firewall_rules  = []
    }
  }

  container_definitions = {
    "ct-vpn" = {
      hostname        = "ct-vpn"
      cores           = 1
      memory          = 1024
      disk_size       = 10
      ipaddr          = "192.168.1.11/24"
      firewall_enable = true
      firewall_rules = [
        {
          action  = "ACCEPT"
          type    = "in"
          proto   = "tcp"
          dport   = "22"
          comment = "Allow SSH"
        },
        {
          action  = "ACCEPT"
          type    = "in"
          proto   = "udp"
          dport   = "51820"
          comment = "Allow Wireguard"
        },
        {
          action  = "DROP"
          type    = "in"
          comment = "Drop all other incoming traffic"
        }
      ]
    }
  }
}

module "vm" {
  # Parametrized VM module — reusable across environments
  source   = "../../modules/vm"
  for_each = local.vm_definitions

  # General
  name      = each.key
  hostname  = each.value.hostname
  node_name = var.node_name

  # CPU / RAM / Disk / PCI
  cores         = each.value.cores
  memory        = each.value.memory
  disk_size     = each.value.disk_size
  disk_storage  = var.disk_storage
  disk_image_id = module.ubuntu_image.image_id
  virtiofs      = each.value.virtiofs
  pci_devices   = each.value.pci_devices

  # Network
  ipaddr      = each.value.ipaddr
  gateway     = var.gateway
  nameservers = var.nameservers

  # Cloud-init user config
  user           = var.user
  ssh_public_key = file(var.ssh_public_key)
  timezone       = var.timezone
  locale         = var.locale

  snippets_storage    = var.snippets_storage
  snippets_node_name  = var.snippets_node_name
  cloud_init_template = "cloud-init-base.yaml.tftpl"

  # Firewall
  firewall_enable = each.value.firewall_enable
  firewall_rules  = each.value.firewall_rules
}

module "container" {
  # Parametrized container module — reusable across environments
  source   = "../../modules/container"
  for_each = local.container_definitions

  # General
  hostname  = each.value.hostname
  node_name = var.node_name

  # CPU / RAM / Disk
  cores         = each.value.cores
  memory        = each.value.memory
  disk_size     = each.value.disk_size
  disk_storage  = var.disk_storage
  disk_image_id = module.ubuntu_lxc_image.image_id

  # Network
  ipaddr      = each.value.ipaddr
  gateway     = var.gateway
  nameservers = var.nameservers

  # System config
  ssh_public_key = file(var.ssh_public_key)

  # Firewall
  firewall_enable = each.value.firewall_enable
  firewall_rules  = each.value.firewall_rules
}
