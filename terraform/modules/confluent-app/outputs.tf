output "service_account_id" {
  description = "Confluent runtime service account ID (passed through from input)"
  value       = var.runtime_service_account_id
}

output "topic_names" {
  description = "List of created topic names"
  value       = [for t in confluent_kafka_topic.this : t.topic_name]
}
