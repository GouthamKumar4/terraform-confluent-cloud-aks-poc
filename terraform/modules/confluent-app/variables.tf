variable "team_name" {
  description = "Team name (used in service account description)"
  type        = string
}

variable "service_account_name" {
  description = "Display name for the Confluent service account"
  type        = string
}

variable "cluster_id" {
  description = "Confluent Kafka cluster ID (from platform Key Vault)"
  type        = string
}

variable "environment_id" {
  description = "Confluent environment ID (from platform Key Vault)"
  type        = string
}

variable "rest_endpoint" {
  description = "Kafka cluster REST endpoint (from platform Key Vault)"
  type        = string
}

variable "topics" {
  description = "List of topics to create for this team"
  type = list(object({
    name       = string
    partitions = number
    config     = optional(map(string), {})
  }))

  validation {
    condition     = length(var.topics) > 0
    error_message = "At least one topic must be defined."
  }

  validation {
    condition     = alltrue([for t in var.topics : t.partitions >= 1 && t.partitions <= 256])
    error_message = "Topic partitions must be between 1 and 256."
  }

  validation {
    condition     = alltrue([for t in var.topics : can(regex("^[a-zA-Z0-9._-]+$", t.name))])
    error_message = "Topic names must contain only alphanumeric characters, dots, hyphens, or underscores."
  }
}

variable "consumer_group_prefix" {
  description = "Prefix for consumer group ACL (e.g., orders-, payments-)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.consumer_group_prefix))
    error_message = "consumer_group_prefix must start with alphanumeric and contain only lowercase letters, numbers, and hyphens."
  }
}
