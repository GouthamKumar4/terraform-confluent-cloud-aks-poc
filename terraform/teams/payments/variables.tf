variable "azure_subscription_id" {
  description = "Azure subscription ID (for Key Vault access)"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (org-level)"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret (org-level)"
  type        = string
  sensitive   = true
}

variable "key_vault_id" {
  description = "Resource ID of the platform Key Vault (to read cluster metadata and write app secrets)"
  type        = string
}

variable "team_name" {
  description = "Team name"
  type        = string
}

variable "service_account_name" {
  description = "Confluent service account display name"
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
