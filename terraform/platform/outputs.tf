output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output "confluent_environment_id" {
  description = "Confluent environment ID"
  value       = module.confluent.environment_id
}

output "confluent_cluster_id" {
  description = "Confluent Kafka cluster ID"
  value       = module.confluent.cluster_id
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.networking.vnet_id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL for workload identity"
  value       = module.aks.oidc_issuer_url
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = module.keyvault.vault_uri
}

output "keyvault_id" {
  description = "Key Vault resource ID (pass to app teams for secret read/write)"
  value       = module.keyvault.vault_id
}

output "keyvault_name" {
  description = "Key Vault name"
  value       = module.keyvault.vault_name
}

# --- Deployer Identity (bootstrap reference) ---
output "deployer_identity_name" {
  description = "Managed Identity name used for Terraform deployments"
  value       = data.azurerm_user_assigned_identity.deployer.name
}

output "deployer_identity_client_id" {
  description = "Managed Identity client ID (ARM_CLIENT_ID for CI/CD)"
  value       = data.azurerm_user_assigned_identity.deployer.client_id
}
