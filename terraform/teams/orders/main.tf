###############################################################################
# POC Environment — Root Module
# Composes: Confluent, Networking, AKS, Key Vault modules
# Naming: uses local.names from locals.tf (format: <prefix>-<team>-<env>-<suffix>)
#
# Authentication:
#   Azure:     Managed Identity (id-terraform-unpr-poc-001) + OIDC federation
#              → ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_USE_OIDC=true
#              → No ARM_CLIENT_SECRET needed
#   Confluent: Cloud API key/secret via TF_VAR_* env vars
###############################################################################

# --- Deployer Identity (created manually in Runbook Step B) ---
# This data source references the pre-existing Managed Identity used by Terraform.
# It is NOT created by Terraform — it exists in the bootstrap resource group.
data "azurerm_user_assigned_identity" "deployer" {
  name                = "id-terraform-${var.team_name}-${var.environment_short}-${var.unique_suffix}"
  resource_group_name = "rg-tfstate-${var.team_name}-${var.environment_short}-${var.unique_suffix}"
}

# Resource Group
resource "azurerm_resource_group" "this" {
  name     = local.names.rg
  location = var.location
  tags     = local.common_tags
}

# --- Log Analytics Workspace (for AKS Container Insights) ---
resource "azurerm_log_analytics_workspace" "this" {
  name                = local.names.law
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# --- Confluent Module ---
module "confluent" {
  source = "../../modules/confluent"

  environment_name      = local.names.confluent_env
  cluster_name          = local.names.confluent_cluster
  confluent_region      = var.confluent_region
  cku_count             = var.confluent_cku_count
  azure_subscription_id = var.azure_subscription_id
  service_account_name  = local.names.confluent_sa
  consumer_group_prefix = var.consumer_group_prefix
  topics                = var.topics
}

# --- Networking Module ---
module "networking" {
  source = "../../modules/networking"

  vnet_name           = local.names.vnet
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  vnet_address_space  = var.vnet_address_space
  pe_subnet_prefix    = var.pe_subnet_prefix
  aks_subnet_prefix   = var.aks_subnet_prefix

  # From Confluent's network — their PL service aliases for your PE to connect to
  confluent_private_link_service_aliases = module.confluent.private_link_service_aliases
  confluent_dns_zone_name                = module.confluent.confluent_dns_domain
  confluent_dns_record_name              = "*"

  tags = local.common_tags
}

# --- AKS Module ---
module "aks" {
  source = "../../modules/aks"

  cluster_name        = local.names.aks
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "${local.env_short}-${local.suffix}"
  kubernetes_version  = var.kubernetes_version
  node_count          = var.aks_node_count
  vm_size             = var.aks_vm_size
  subnet_id           = module.networking.aks_subnet_id
  service_cidr        = var.aks_service_cidr
  dns_service_ip      = var.aks_dns_service_ip

  log_analytics_workspace_id      = azurerm_log_analytics_workspace.this.id
  api_server_authorized_ip_ranges = var.aks_authorized_ip_ranges
  private_cluster_enabled         = var.aks_private_cluster_enabled
  admin_group_object_ids          = var.aks_admin_group_object_ids

  tags = local.common_tags
}

# --- Key Vault Module (generic — no Confluent dependency inside) ---
module "keyvault" {
  source = "../../modules/keyvault"

  vault_name          = local.names.kv
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allowed_ip_ranges   = var.keyvault_allowed_ips

  # Grant AKS identity read access to secrets
  reader_principal_ids = {
    "aks-kubelet" = module.aks.kubelet_identity_object_id
  }

  # Push Confluent secrets from HERE (root module), not inside KV module
  secrets = {
    "confluent-api-key-id"     = module.confluent.api_key_id
    "confluent-api-key-secret" = module.confluent.api_key_secret
    "kafka-bootstrap-endpoint" = module.confluent.cluster_bootstrap_endpoint
  }

  tags = local.common_tags
}
