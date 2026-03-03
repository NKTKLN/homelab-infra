output "id" {
  description = "Proxmox VM ID of the created VM"
  value       = proxmox_virtual_environment_vm.vm.id
}

output "vm_password" {
  description = "Default user password for the VM (explicit or generated)"
  value       = local.vm_password
  sensitive   = true
}
