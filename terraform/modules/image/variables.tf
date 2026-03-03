variable "node_name" {
  description = "Proxmox node where the image will be downloaded"
  type        = string
  default     = "pve"
}

variable "disk_image_storage" {
  description = "Proxmox storage where the downloaded image will be stored"
  type        = string
  default     = "local"
}

variable "image_url" {
  description = "URL of the Ubuntu cloud image to download"
  type        = string
}

variable "image_file_name" {
  description = "File name to save the downloaded cloud image as"
  type        = string
}

variable "content_type" {
  description = "Proxmox content type to store the image (import, iso, vztmpl)"
  type        = string

  validation {
    condition     = contains(["import", "iso", "vztmpl"], var.content_type)
    error_message = "content_type must be one of: import, iso, vztmpl."
  }
}
