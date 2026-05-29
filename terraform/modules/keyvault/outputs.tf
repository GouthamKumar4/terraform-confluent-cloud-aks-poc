output "vault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.this.id
}

output "vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.this.vault_uri
}

output "vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "secret_uris" {
  description = "Map of secret name → versionless URI"
  value       = { for k, v in azurerm_key_vault_secret.this : k => v.versionless_id }
  sensitive   = true
}
