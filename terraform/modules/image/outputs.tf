output "image_id" {
  description = "ID of the downloaded image"
  value       = proxmox_virtual_environment_download_file.image.id
}
