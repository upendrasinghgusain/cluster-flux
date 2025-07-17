output "vm_public_ips" {
  description = "Public IP addresses of the VMs"
  value       = azurerm_public_ip.vm_public_ip[*].ip_address
}

output "master_ip" {
  value = azurerm_linux_virtual_machine.vm[0].public_ip_address
}

output "worker_ips" {
  value = [
    for i in range(1, length(azurerm_linux_virtual_machine.vm)) :
    azurerm_linux_virtual_machine.vm[i].public_ip_address
  ]
}

