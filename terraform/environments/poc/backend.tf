terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-unpr-poc-001"
    storage_account_name = "sttfstateunprpoc001"
    container_name       = "sc-tfstate-unpr-poc-001"
    key                  = "unpr-poc/terraform.tfstate"
  }
}
