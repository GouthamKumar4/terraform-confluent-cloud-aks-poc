###############################################################################
# Confluent App Module — Team-level resources
# Creates: Service Account, API Key, Topics, ACLs
#
# Runs from self-hosted runner (AKS pod) inside VNet because topics and ACLs
# use the Kafka REST API (data plane), only reachable via PrivateLink.
###############################################################################

# Service Account — one per team
resource "confluent_service_account" "this" {
  display_name = var.service_account_name
  description  = "Service account for ${var.team_name} team Kafka access"
}

# API Key for the service account
resource "confluent_api_key" "this" {
  display_name           = "${var.service_account_name}-api-key"
  description            = "API key for ${var.service_account_name}"
  disable_wait_for_ready = true

  owner {
    id          = confluent_service_account.this.id
    api_version = confluent_service_account.this.api_version
    kind        = confluent_service_account.this.kind
  }

  managed_resource {
    id          = var.cluster_id
    api_version = "cmk/v2"
    kind        = "Cluster"

    environment {
      id = var.environment_id
    }
  }
}

# --- Topics (data plane — requires PrivateLink connectivity) ---
resource "confluent_kafka_topic" "this" {
  for_each = { for t in var.topics : t.name => t }

  kafka_cluster {
    id = var.cluster_id
  }

  topic_name       = each.value.name
  partitions_count = each.value.partitions
  rest_endpoint    = var.rest_endpoint

  config = each.value.config

  credentials {
    key    = confluent_api_key.this.id
    secret = confluent_api_key.this.secret
  }
}

# --- ACLs (data plane — requires PrivateLink connectivity) ---

# WRITE access per topic
resource "confluent_kafka_acl" "producer" {
  for_each = { for t in var.topics : t.name => t }

  kafka_cluster {
    id = var.cluster_id
  }

  resource_type = "TOPIC"
  resource_name = each.value.name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.this.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = var.rest_endpoint

  credentials {
    key    = confluent_api_key.this.id
    secret = confluent_api_key.this.secret
  }

  depends_on = [confluent_kafka_topic.this]
}

# READ access per topic
resource "confluent_kafka_acl" "consumer" {
  for_each = { for t in var.topics : t.name => t }

  kafka_cluster {
    id = var.cluster_id
  }

  resource_type = "TOPIC"
  resource_name = each.value.name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.this.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = var.rest_endpoint

  credentials {
    key    = confluent_api_key.this.id
    secret = confluent_api_key.this.secret
  }

  depends_on = [confluent_kafka_topic.this]
}

# Consumer group access
resource "confluent_kafka_acl" "consumer_group" {
  kafka_cluster {
    id = var.cluster_id
  }

  resource_type = "GROUP"
  resource_name = var.consumer_group_prefix
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.this.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = var.rest_endpoint

  credentials {
    key    = confluent_api_key.this.id
    secret = confluent_api_key.this.secret
  }
}
