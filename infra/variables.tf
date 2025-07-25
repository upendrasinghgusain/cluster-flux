variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "clusterflux"
}

variable "subscription_id" {
  description = "subscription id"
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-clusterflux"
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "UK South"
}

variable "vm_count" {
  description = "Number of Linux VMs"
  type        = number
  default     = 3
}

variable "vm_size" {
  description = "Size of the VMs"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the Linux VMs"
  type        = string
  default     = "upendragusain"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
