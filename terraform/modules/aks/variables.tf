variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string

  validation {
    condition     = length(var.cluster_name) >= 1 && length(var.cluster_name) <= 63
    error_message = "cluster_name must be 1-63 characters."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,53}$", var.dns_prefix))
    error_message = "dns_prefix must start with a letter, contain only lowercase alphanumeric and hyphens, max 54 chars."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be in major.minor format (e.g., 1.29, 1.30)."
  }
}

variable "node_count" {
  description = "Number of nodes in the default pool"
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 1000
    error_message = "node_count must be between 1 and 1000."
  }
}

variable "vm_size" {
  description = "VM size for the default node pool"
  type        = string
  default     = "Standard_D2s_v5"

  validation {
    condition     = can(regex("^Standard_", var.vm_size))
    error_message = "vm_size must be a valid Azure VM SKU starting with 'Standard_'."
  }
}

variable "sku_tier" {
  description = "AKS SKU tier: Free (no SLA) or Standard (99.95% SLA)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be 'Free' or 'Standard'."
  }
}

variable "subnet_id" {
  description = "Subnet ID for the AKS nodes"
  type        = string

  validation {
    condition     = length(var.subnet_id) > 0
    error_message = "subnet_id must not be empty."
  }
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "service_cidr must be valid CIDR notation."
  }
}

variable "dns_service_ip" {
  description = "DNS service IP (must be within service_cidr)"
  type        = string
  default     = "10.1.0.10"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.dns_service_ip))
    error_message = "dns_service_ip must be a valid IPv4 address."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# --- Cluster Upgrades & Maintenance ---

variable "automatic_upgrade_channel" {
  description = "K8s auto-upgrade channel: none, patch, stable, rapid, or node-image"
  type        = string
  default     = "patch"

  validation {
    condition     = contains(["none", "patch", "stable", "rapid", "node-image"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be one of: none, patch, stable, rapid, node-image."
  }
}

variable "node_os_upgrade_channel" {
  description = "Node OS auto-upgrade channel: None, Unmanaged, SecurityPatch, or NodeImage"
  type        = string
  default     = "SecurityPatch"

  validation {
    condition     = contains(["None", "Unmanaged", "SecurityPatch", "NodeImage"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be one of: None, Unmanaged, SecurityPatch, NodeImage."
  }
}

variable "os_disk_type" {
  description = "OS disk type for node pools: Managed or Ephemeral"
  type        = string
  default     = "Managed"

  validation {
    condition     = contains(["Managed", "Ephemeral"], var.os_disk_type)
    error_message = "os_disk_type must be 'Managed' or 'Ephemeral'."
  }
}

variable "max_surge" {
  description = "Max surge percentage for node pool upgrades (e.g., 33%)"
  type        = string
  default     = "33%"
}

variable "image_cleaner_enabled" {
  description = "Enable automatic stale image cleanup on nodes"
  type        = bool
  default     = true
}

variable "image_cleaner_interval_hours" {
  description = "Interval in hours for image cleaner runs"
  type        = number
  default     = 48

  validation {
    condition     = var.image_cleaner_interval_hours >= 24 && var.image_cleaner_interval_hours <= 720
    error_message = "image_cleaner_interval_hours must be between 24 and 720."
  }
}

variable "api_server_authorized_ip_ranges" {
  description = "List of CIDR ranges authorized to access the AKS API server (empty = unrestricted)"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.api_server_authorized_ip_ranges : can(cidrhost(cidr, 0))])
    error_message = "All entries must be valid CIDR notation (e.g., 203.0.113.0/24)."
  }
}

# --- Authentication & Authorization ---

variable "private_cluster_enabled" {
  description = "Enable private cluster (API server gets private IP only, no public access)"
  type        = bool
  default     = false
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for private cluster. Use 'System' for auto-managed, 'None' to skip, or a zone resource ID."
  type        = string
  default     = "System"

  validation {
    condition     = var.private_dns_zone_id == "System" || var.private_dns_zone_id == "None" || can(regex("^/subscriptions/", var.private_dns_zone_id))
    error_message = "private_dns_zone_id must be 'System', 'None', or a full Azure resource ID."
  }
}

variable "admin_group_object_ids" {
  description = "List of Entra ID (AAD) group object IDs that receive cluster-admin access"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.admin_group_object_ids : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "admin_group_object_ids must contain valid UUID format object IDs."
  }
}

variable "local_account_disabled" {
  description = "Disable Kubernetes local accounts (set true in production to enforce AAD-only auth)"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for Container Insights (OMS agent)"
  type        = string
}
