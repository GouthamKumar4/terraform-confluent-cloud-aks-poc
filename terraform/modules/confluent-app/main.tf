###############################################################################
# Confluent App Module — Team-level resources
# Creates: Topics, ACLs
#
# Runs from self-hosted runner (AKS pod) inside VNet because topics and ACLs
# use the Kafka REST API (data plane), only reachable via PrivateLink.
#
# NOTE: Service accounts and cluster API keys are created manually by cloud
# admin (Runbook Step D.2) and passed as inputs. This allows the deployer SA
# to use ResourceOwner (prefix-scoped) instead of EnvironmentAdmin.
###############################################################################

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
    key    = var.runtime_api_key_id
    secret = var.runtime_api_key_secret
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
  principal     = "User:${var.runtime_service_account_id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = var.rest_endpoint

  credentials {
    key    = var.runtime_api_key_id
    secret = var.runtime_api_key_secret
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
  principal     = "User:${var.runtime_service_account_id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = var.rest_endpoint

  credentials {
    key    = var.runtime_api_key_id
    secret = var.runtime_api_key_secret
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
  principal     = "User:${var.runtime_service_account_id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = var.rest_endpoint

  credentials {
    key    = var.runtime_api_key_id
    secret = var.runtime_api_key_secret
  }
}
