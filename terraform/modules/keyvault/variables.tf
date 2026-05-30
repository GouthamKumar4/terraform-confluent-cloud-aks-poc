variable "vault_name" {
  description = "Name of the Key Vault (must be globally unique)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "reader_principal_ids" {
  description = "Map of identity name to principal/object ID that need Key Vault Secrets User role (e.g., AKS identity)"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of secret name → value to store in Key Vault (optional, pass empty map for vault-only)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access Key Vault (for management)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
