###############################################################################
# Provider Configuration
# Azure: for reading Key Vault secrets (cluster metadata)
# Confluent: scoped Cloud API key from GitHub Environment (ResourceOwner)
###############################################################################

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}
