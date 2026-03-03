provider "proxmox" {
  endpoint  = var.pve_api_url
  api_token = "${var.pve_token_id}=${var.pve_token_secret}"
  insecure  = var.pve_tls_insecure

  ssh {
    agent    = true
    username = var.pve_ssh_username
  }
}
