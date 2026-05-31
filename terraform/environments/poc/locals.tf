###############################################################################
# Naming Convention
# Format:  <caf-prefix>-<team>-<env>-<suffix>
# All resources use the team name for consistency.
#
# Examples:
#   Azure:     rg-unpr-poc-001, vnet-unpr-poc-001, aks-unpr-poc-001
#   Confluent: kafka-unpr-poc-001, sa-app-unpr-poc-001
#   Bootstrap: rg-tfstate-unpr-poc-001, sttfstateunprpoc001, id-terraform-unpr-poc-001
###############################################################################

# ─── Azure CAF Naming (for_each over all Azure resources) ────────────────

locals {
  # Team-qualified name: <team>-<env>  →  e.g., "unpr-poc"
  team_env = "${var.team_name}-${var.environment_short}"

  # Define all Azure resources that need CAF naming
  azure_resource_names = {
    rg       = { resource_type = "azurerm_resource_group", name = local.team_env }
    vnet     = { resource_type = "azurerm_virtual_network", name = local.team_env }
    snet_pe  = { resource_type = "azurerm_subnet", name = "${local.team_env}-pe" }
    snet_aks = { resource_type = "azurerm_subnet", name = "${local.team_env}-aks" }
    nsg_pe   = { resource_type = "azurerm_network_security_group", name = "${local.team_env}-pe" }
    nsg_aks  = { resource_type = "azurerm_network_security_group", name = "${local.team_env}-aks" }
    pe       = { resource_type = "azurerm_private_endpoint", name = local.team_env }
    aks      = { resource_type = "azurerm_kubernetes_cluster", name = local.team_env }
    kv       = { resource_type = "azurerm_key_vault", name = local.team_env }
    law      = { resource_type = "azurerm_log_analytics_workspace", name = local.team_env }
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
      # Confluent Cloud Resources (same team name pattern)
      confluent_env     = local.env_short
      confluent_network = "net-${local.team_env}-${local.suffix}"
      confluent_cluster = "kafka-${local.team_env}-${local.suffix}"
      confluent_sa      = "sa-app-${local.team_env}-${local.suffix}"

      # DNS (fixed by Confluent)
      dns_zone = "privatelink.confluent.cloud"
    }
  )

  # Common tags for all Azure resources
  common_tags = merge(var.tags, {
    environment = local.env_short
    team        = var.team_name
    region      = var.location
    managed_by  = "terraform"
  })
}
