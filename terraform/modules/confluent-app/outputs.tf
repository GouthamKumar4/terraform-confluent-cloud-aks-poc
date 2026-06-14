output "service_account_id" {
  description = "Confluent service account ID"
  value       = confluent_service_account.this.id
}

output "api_key_id" {
  description = "API key ID"
  value       = confluent_api_key.this.id
}

output "api_key_secret" {
  description = "API key secret — store in Key Vault, never expose"
  value       = confluent_api_key.this.secret
  sensitive   = true
}

output "topic_names" {
  description = "List of created topic names"
  value       = [for t in confluent_kafka_topic.this : t.topic_name]
}
