###############################################################################
# Orders Team Deployment
# Creates: Topics, ACLs
#
# Runs from: Self-hosted GitHub Actions runner (AKS pod inside VNet)
# Reads from: Platform Key Vault (cluster_id, environment_id, rest_endpoint)
# Authenticates via: Per-team deployer Cloud API key from GitHub Environment
#                    (ResourceOwner on orders*)
# Runtime SA + cluster API key also from GitHub Environment secrets
###############################################################################

# --- Read platform outputs from Key Vault ---
data "azurerm_key_vault_secret" "cluster_id" {
  name         = "confluent-cluster-id"
  key_vault_id = var.key_vault_id
}

data "azurerm_key_vault_secret" "environment_id" {
  name         = "confluent-environment-id"
  key_vault_id = var.key_vault_id
}

data "azurerm_key_vault_secret" "rest_endpoint" {
  name         = "confluent-rest-endpoint"
  key_vault_id = var.key_vault_id
}

# --- Confluent App Module (topics + ACLs only) ---
module "confluent_app" {
  source = "../../modules/confluent-app"

  team_name                  = var.team_name
  runtime_service_account_id = var.runtime_service_account_id
  runtime_api_key_id         = var.runtime_api_key_id
  runtime_api_key_secret     = var.runtime_api_key_secret
  cluster_id                 = data.azurerm_key_vault_secret.cluster_id.value
  environment_id             = data.azurerm_key_vault_secret.environment_id.value
  rest_endpoint              = data.azurerm_key_vault_secret.rest_endpoint.value
  topics                     = var.topics
  consumer_group_prefix      = var.consumer_group_prefix
}
