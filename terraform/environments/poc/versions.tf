###############################################################################
# Terraform Settings
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.74"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~> 1.2"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.73"
    }
  }
}
