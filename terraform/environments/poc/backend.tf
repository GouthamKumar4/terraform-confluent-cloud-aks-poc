terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "yourprojtfstate"
    container_name       = "tfstate"
    key                  = "poc/confluent-kafka/poc.tfstate"
  }
}
