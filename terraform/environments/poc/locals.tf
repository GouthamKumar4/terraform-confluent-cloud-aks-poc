###############################################################################
# Naming Convention (Hybrid)
# Azure resources:     Azure CAF provider (Microsoft Cloud Adoption Framework)
# Confluent resources: Manual naming (CAF doesn't support them)
###############################################################################

# ─── Azure CAF Naming (for_each over all Azure resources) ────────────────

locals {
  # Define all Azure resources that need CAF naming
  azure_resource_names = {
    rg       = { resource_type = "azurerm_resource_group",           name = var.environment_short }
    vnet     = { resource_type = "azurerm_virtual_network",          name = var.environment_short }
    snet_pe  = { resource_type = "azurerm_subnet",                   name = "${var.environment_short}-pe" }
    snet_aks = { resource_type = "azurerm_subnet",                   name = "${var.environment_short}-aks" }
    nsg_pe   = { resource_type = "azurerm_network_security_group",   name = "${var.environment_short}-pe" }
    nsg_aks  = { resource_type = "azurerm_network_security_group",   name = "${var.environment_short}-aks" }
    pe       = { resource_type = "azurerm_private_endpoint",         name = "${var.environment_short}-kafka" }
    aks      = { resource_type = "azurerm_kubernetes_cluster",       name = var.environment_short }
    kv       = { resource_type = "azurerm_key_vault",                name = var.environment_short }
    law      = { resource_type = "azurerm_log_analytics_workspace",  name = var.environment_short }
  }
}

resource "azurecaf_name" "this" {
  for_each = local.azure_resource_names

  name          = each.value.name
  resource_type = each.value.resource_type
  suffixes      = [var.unique_suffix]
  clean_input   = true
}

# ─── Locals: Combine CAF names + manual Confluent names ──────────────────

locals {
  env_short = var.environment_short
  suffix    = var.unique_suffix

  # Azure resource names (from CAF provider via for_each)
  names = merge(
    { for k, v in azurecaf_name.this : k => v.result },
    {
      # Confluent Cloud Resources (manual — not in Azure, CAF doesn't apply)
      confluent_network = "net-kafka-${local.env_short}-${local.suffix}"
      confluent_cluster = "kafka-${local.env_short}-${local.suffix}"
      confluent_sa      = "sa-app-${local.env_short}-${local.suffix}"

      # DNS (fixed by Confluent)
      dns_zone = "privatelink.confluent.cloud"
    }
  )

  # Common tags for all Azure resources
  common_tags = merge(var.tags, {
    environment = local.env_short
    region      = var.location
    managed_by  = "terraform"
  })
}
