output "vm_public_ips" {
  description = "Public IP addresses of the VMs"
  value       = azurerm_public_ip.vm_public_ip[*].ip_address
}
