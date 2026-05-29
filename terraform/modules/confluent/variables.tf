variable "environment_id" {
  description = "Existing Confluent Cloud environment ID created manually before running Terraform (for example, env-abc123)."
  type        = string

  validation {
    condition     = can(regex("^env-[a-zA-Z0-9]+$", var.environment_id))
    error_message = "environment_id must be a Confluent Cloud environment ID, for example env-abc123."
  }
}

variable "cluster_name" {
  description = "Display name for the Kafka cluster"
  type        = string
}

variable "confluent_region" {
  description = "Confluent Cloud region (e.g., westeurope)"
  type        = string
}

variable "cku_count" {
  description = "Number of Confluent Kafka Units for Dedicated cluster"
  type        = number
  default     = 1
}

variable "azure_subscription_id" {
  description = "Azure subscription ID allowed for Private Link access"
  type        = string
}

variable "confluent_availability_zones" {
  description = "Confluent Cloud availability zones (e.g., [\"1\", \"2\", \"3\"] for Azure)"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "service_account_name" {
  description = "Display name for the Confluent service account"
  type        = string
}

variable "consumer_group_prefix" {
  description = "Prefix for consumer group ACL"
  type        = string
  default     = "poc-"
}

variable "topics" {
  description = "List of topics to create"
  type = list(object({
    name       = string
    partitions = number
    config     = optional(map(string), {})
  }))
  default = [
    { name = "orders", partitions = 3, config = {} },
    { name = "payments", partitions = 3, config = {} }
  ]
}
