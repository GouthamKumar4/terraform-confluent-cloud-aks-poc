variable "environment_name" {
  description = "Display name for the Confluent Cloud environment"
  type        = string
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
