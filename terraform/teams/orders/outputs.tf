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

output "confluent_topic_names" {
  description = "Created Kafka topic names"
  value       = module.confluent.topic_names
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

output "keyvault_secret_uris" {
  description = "Map of secret name to versionless Key Vault secret URI"
  value       = module.keyvault.secret_uris
  sensitive   = true
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
