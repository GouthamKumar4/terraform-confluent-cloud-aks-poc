variable "azure_subscription_id" {
  description = "Azure subscription ID (for Key Vault access)"
  type        = string
  sensitive   = true
}

variable "key_vault_id" {
  description = "Resource ID of the platform Key Vault (to read cluster metadata)"
  type        = string
}

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (per-team deployer, ResourceOwner — from GitHub Environment)"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret (per-team deployer — from GitHub Environment)"
  type        = string
  sensitive   = true
}

variable "runtime_service_account_id" {
  description = "Confluent runtime service account ID (from GitHub Environment)"
  type        = string
}

variable "runtime_api_key_id" {
  description = "Confluent runtime cluster API key ID (from GitHub Environment)"
  type        = string
  sensitive   = true
}

variable "runtime_api_key_secret" {
  description = "Confluent runtime cluster API key secret (from GitHub Environment)"
  type        = string
  sensitive   = true
}

variable "team_name" {
  description = "Team name"
  type        = string
}

variable "topics" {
  description = "Kafka topics to create for this team"
  type = list(object({
    name       = string
    partitions = number
    config     = optional(map(string), {})
  }))
}

variable "consumer_group_prefix" {
  description = "Consumer group prefix for ACLs"
  type        = string
}
