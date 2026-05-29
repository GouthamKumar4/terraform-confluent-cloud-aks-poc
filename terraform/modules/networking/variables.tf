variable "vnet_name" {
  description = "Name of the Virtual Network"
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

variable "vnet_address_space" {
  description = "Address space for the VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "pe_subnet_prefix" {
  description = "CIDR prefix for the private endpoint subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "aks_subnet_prefix" {
  description = "CIDR prefix for the AKS subnet"
  type        = string
  default     = "10.0.2.0/22"
}

variable "confluent_private_link_service_aliases" {
  description = "Map of zone to Private Link Service alias from Confluent network (e.g., {\"1\" = \"alias1\", \"2\" = \"alias2\"})"
  type        = map(string)
}

variable "confluent_pe_zone" {
  description = "Which Confluent zone's PL alias to use for the PE (e.g., \"1\")"
  type        = string
  default     = "1"
}

variable "confluent_dns_zone_name" {
  description = "Private DNS zone name for Confluent (e.g., privatelink.confluent.cloud)"
  type        = string
  default     = "privatelink.confluent.cloud"
}

variable "confluent_dns_record_name" {
  description = "DNS A record name for Confluent bootstrap"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
