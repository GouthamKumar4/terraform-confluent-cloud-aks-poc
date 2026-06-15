###############################################################################
# Backend: Partial config — values provided via -backend-config=backend-<env>.hcl
# Usage:   terraform init -backend-config=backend-poc.hcl
###############################################################################
terraform {
  backend "azurerm" {}
}
