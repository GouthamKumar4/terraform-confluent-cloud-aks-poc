###############################################################################
# Payments Team Deployment
# Creates: Service Account, API Key, Topics, ACLs
#
# Runs from: Self-hosted GitHub Actions runner (AKS pod inside VNet)
# Reads from: Platform Key Vault (cluster_id, environment_id, rest_endpoint)
# Writes to: Platform Key Vault (api-key-id, api-key-secret for AKS pods)
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

# --- Confluent App Module (topics + SA + ACLs) ---
module "confluent_app" {
  source = "../../modules/confluent-app"

  team_name             = var.team_name
  service_account_name  = var.service_account_name
  cluster_id            = data.azurerm_key_vault_secret.cluster_id.value
  environment_id        = data.azurerm_key_vault_secret.environment_id.value
  rest_endpoint         = data.azurerm_key_vault_secret.rest_endpoint.value
  topics                = var.topics
  consumer_group_prefix = var.consumer_group_prefix
}

# --- Write app secrets back to Key Vault (for AKS pods to consume) ---
resource "azurerm_key_vault_secret" "api_key_id" {
  name         = "${var.team_name}-confluent-api-key-id"
  value        = module.confluent_app.api_key_id
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "api_key_secret" {
  name         = "${var.team_name}-confluent-api-key-secret"
  value        = module.confluent_app.api_key_secret
  key_vault_id = var.key_vault_id
}
