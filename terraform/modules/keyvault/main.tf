###############################################################################
# Key Vault Module (Generic, Reusable)
# Creates: Key Vault with RBAC + optionally stores secrets passed as a map
###############################################################################

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                       = var.vault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  rbac_authorization_enabled = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
  }

  tags = var.tags
}

# RBAC: Deployer (current principal) gets Secrets Officer to write secrets
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# RBAC: Additional identities that need read access (e.g., AKS)
resource "azurerm_role_assignment" "secrets_user" {
  for_each = var.reader_principal_ids

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

# Optional: Store secrets if provided (generic map — not tied to any service)
resource "azurerm_key_vault_secret" "this" {
  for_each = nonsensitive(toset(keys(var.secrets)))

  name         = each.value
  value        = var.secrets[each.value]
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}
