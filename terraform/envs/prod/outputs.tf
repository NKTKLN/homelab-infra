output "vm_passwords" {
  description = "Default user passwords for VMs"
  value       = { for name, m in module.vm : name => m.vm_password }
  sensitive   = true
}

output "container_passwords" {
  description = "Default user passwords for containers"
  value       = { for name, m in module.container : name => m.container_password }
  sensitive   = true
}
