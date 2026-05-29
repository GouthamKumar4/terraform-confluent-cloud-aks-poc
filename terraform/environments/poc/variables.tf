# --- General ---
variable "environment_short" {
  description = "Short environment name used in naming convention (e.g., poc, dev, stg, prd)"
  type        = string
  default     = "poc"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.environment_short))
    error_message = "environment_short must be 2-5 lowercase letters (e.g., poc, dev, stg, prd)."
  }
}

variable "unique_suffix" {
  description = "Unique numeric suffix to avoid global name collisions (e.g., 001, 042)"
  type        = string
  default     = "001"

  validation {
    condition     = can(regex("^[0-9]{3}$", var.unique_suffix))
    error_message = "unique_suffix must be exactly 3 digits (e.g., 001, 042)."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z]+[a-z0-9]*$", var.location))
    error_message = "location must be a valid Azure region name (e.g., westeurope, eastus2)."
  }
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.azure_subscription_id))
    error_message = "azure_subscription_id must be a valid UUID format."
  }
}

variable "tags" {
  description = "Additional tags (merged with auto-generated common_tags)"
  type        = map(string)
  default = {
    project = "confluent-kafka-poc"
  }
}

# --- Confluent ---
variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (org-level)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.confluent_cloud_api_key) > 0
    error_message = "confluent_cloud_api_key must not be empty."
  }
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret (org-level)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.confluent_cloud_api_secret) > 0
    error_message = "confluent_cloud_api_secret must not be empty."
  }
}

variable "confluent_region" {
  description = "Confluent Cloud region"
  type        = string
  default     = "westeurope"

  validation {
    condition     = can(regex("^[a-z]+[a-z0-9]*$", var.confluent_region))
    error_message = "confluent_region must be a valid region name (e.g., westeurope, eastus2)."
  }
}

variable "confluent_cku_count" {
  description = "CKU count for Dedicated cluster"
  type        = number
  default     = 1

  validation {
    condition     = var.confluent_cku_count >= 1 && var.confluent_cku_count <= 12
    error_message = "confluent_cku_count must be between 1 and 12."
  }
}

variable "consumer_group_prefix" {
  description = "Consumer group prefix for ACL"
  type        = string
  default     = "poc-"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.consumer_group_prefix))
    error_message = "consumer_group_prefix must start with alphanumeric and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "topics" {
  description = "Kafka topics to create"
  type = list(object({
    name       = string
    partitions = number
    config     = optional(map(string), {})
  }))
  default = [
    { name = "orders", partitions = 3, config = {} },
    { name = "payments", partitions = 3, config = {} }
  ]

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

# --- Networking ---
variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition     = length(var.vnet_address_space) > 0
    error_message = "At least one address space CIDR must be provided."
  }

  validation {
    condition     = alltrue([for cidr in var.vnet_address_space : can(cidrhost(cidr, 0))])
    error_message = "All entries must be valid CIDR notation (e.g., 10.0.0.0/16)."
  }
}

variable "pe_subnet_prefix" {
  description = "Private endpoint subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.pe_subnet_prefix, 0))
    error_message = "pe_subnet_prefix must be valid CIDR notation (e.g., 10.0.1.0/24)."
  }
}

variable "aks_subnet_prefix" {
  description = "AKS subnet CIDR"
  type        = string
  default     = "10.0.4.0/22"

  validation {
    condition     = can(cidrhost(var.aks_subnet_prefix, 0))
    error_message = "aks_subnet_prefix must be valid CIDR notation (e.g., 10.0.4.0/22)."
  }
}

# --- AKS ---
variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.29"
}

variable "aks_node_count" {
  description = "AKS node count"
  type        = number
  default     = 2

  validation {
    condition     = var.aks_node_count >= 1 && var.aks_node_count <= 5
    error_message = "aks_node_count must be between 1 and 5 for POC environment."
  }
}

variable "aks_vm_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "aks_service_cidr" {
  description = "AKS service CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "AKS DNS service IP"
  type        = string
  default     = "10.1.0.10"
}

variable "aks_authorized_ip_ranges" {
  description = "CIDR ranges authorized to access AKS API server (ignored when private cluster is enabled)"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.aks_authorized_ip_ranges : can(cidrhost(cidr, 0))])
    error_message = "aks_authorized_ip_ranges must contain valid CIDR ranges (e.g., 203.0.113.0/24)."
  }
}

variable "aks_private_cluster_enabled" {
  description = "Enable AKS private cluster (API server only via private IP)"
  type        = bool
  default     = true
}

variable "aks_admin_group_object_ids" {
  description = "Entra ID group object IDs for AKS cluster-admin access"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.aks_admin_group_object_ids : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "aks_admin_group_object_ids must contain valid UUID format object IDs."
  }
}

# --- Key Vault ---
variable "keyvault_allowed_ips" {
  description = "IP ranges allowed to access Key Vault"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.keyvault_allowed_ips : can(cidrhost("${ip}/32", 0)) || can(cidrhost(ip, 0))])
    error_message = "keyvault_allowed_ips must contain valid IP addresses or CIDR ranges."
  }
}
