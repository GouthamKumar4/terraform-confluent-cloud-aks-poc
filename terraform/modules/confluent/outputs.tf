output "environment_id" {
  description = "Confluent environment ID"
  value       = var.environment_id
}

output "cluster_id" {
  description = "Kafka cluster ID"
  value       = confluent_kafka_cluster.this.id
}

output "cluster_bootstrap_endpoint" {
  description = "Kafka cluster bootstrap endpoint"
  value       = confluent_kafka_cluster.this.bootstrap_endpoint
  sensitive   = true
}

output "cluster_rest_endpoint" {
  description = "Kafka cluster REST endpoint"
  value       = confluent_kafka_cluster.this.rest_endpoint
  sensitive   = true
}

output "service_account_id" {
  description = "Service account ID"
  value       = confluent_service_account.app.id
}

output "api_key_id" {
  description = "API key ID (non-sensitive identifier)"
  value       = confluent_api_key.app.id
}

output "api_key_secret" {
  description = "API key secret — store in Key Vault, never expose"
  value       = confluent_api_key.app.secret
  sensitive   = true
}

output "network_id" {
  description = "Confluent network ID"
  value       = confluent_network.this.id
}

output "private_link_service_aliases" {
  description = "Map of Azure zone to Private Link Service alias (use in azurerm_private_endpoint)"
  value       = confluent_network.this.azure[0].private_link_service_aliases
}

output "confluent_dns_domain" {
  description = "DNS domain for the Confluent network (for private DNS zone)"
  value       = confluent_network.this.dns_domain
}

output "topic_names" {
  description = "List of created topic names"
  value       = [for t in confluent_kafka_topic.topics : t.topic_name]
}
