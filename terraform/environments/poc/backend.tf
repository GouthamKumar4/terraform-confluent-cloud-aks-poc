terraform {
  # Configure with backend.hcl after manually creating the Azure Storage
  # account/container prerequisite:
  # terraform init -backend-config=backend.hcl
  backend "azurerm" {}
}
