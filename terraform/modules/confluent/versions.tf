# Required to prevent Terraform from defaulting to "hashicorp/confluent",
# which does not exist in the registry.
terraform {
terraform {
  required_providers {
    confluent = {
      source = "confluentinc/confluent"
    }
  }
}
