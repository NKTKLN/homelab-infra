output "id" {
  description = "Proxmox VM ID of the created container"
  value       = proxmox_virtual_environment_container.container.id
}

output "container_password" {
  description = "Default user password for the container (explicit or generated)"
  value       = local.container_password
  sensitive   = true
}
