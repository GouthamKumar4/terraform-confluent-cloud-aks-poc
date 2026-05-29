output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.this.name
}

output "pe_subnet_id" {
  description = "Private Endpoint subnet ID"
  value       = azurerm_subnet.private_endpoints.id
}

output "aks_subnet_id" {
  description = "AKS subnet ID"
  value       = azurerm_subnet.aks.id
}

output "private_endpoint_ip" {
  description = "Private IP of the Confluent private endpoint"
  value       = azurerm_private_endpoint.confluent.private_service_connection[0].private_ip_address
}

output "private_dns_zone_id" {
  description = "Private DNS zone ID"
  value       = azurerm_private_dns_zone.confluent.id
}
