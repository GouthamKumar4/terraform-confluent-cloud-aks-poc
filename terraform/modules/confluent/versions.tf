# Terraform resolves providers per module. When the confluent module uses confluent_* resources, Terraform looks for where confluent is defined in that module's scope. Without the versions.tf in the module, it defaults to hashicorp/confluent (the implicit convention) — which doesn't exist.
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.73"
    }
  }
}
