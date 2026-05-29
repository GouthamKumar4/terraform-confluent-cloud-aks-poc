###############################################################################
# Confluent Cloud Module
# Creates: Network (PrivateLink), Dedicated Kafka Cluster, Topics,
#          application Service Account, API Key, ACLs, and Private Link Access
###############################################################################

# Existing Confluent Cloud environment
# Create/login and environment setup are manual prerequisites. This module
# references the environment ID passed by the root module.

# Confluent-managed Network (THEIR side — you declare, they manage)
# This is NOT your Azure VNet. This is Confluent's internal network
# that exposes a Private Link Service for your PE to connect to.
resource "confluent_network" "this" {
  display_name     = "${var.cluster_name}-network"
  cloud            = "AZURE"
  region           = var.confluent_region
  connection_types = ["PRIVATELINK"]

  azure {
    subscription = var.azure_subscription_id
  }

  environment {
    id = var.environment_id
  }

  zones = var.confluent_availability_zones
}

# Private Link Access — grants YOUR Azure subscription permission to connect
resource "confluent_private_link_access" "this" {
  display_name = "${var.cluster_name}-pl-access"

  azure {
    subscription = var.azure_subscription_id
  }

  environment {
    id = var.environment_id
  }

  network {
    id = confluent_network.this.id
  }
}

# Kafka Cluster (Dedicated tier, attached to Confluent's PrivateLink network)
resource "confluent_kafka_cluster" "this" {
  display_name = var.cluster_name
  availability = "SINGLE_ZONE"
  cloud        = "AZURE"
  region       = var.confluent_region

  dedicated {
    cku = var.cku_count
  }

  network {
    id = confluent_network.this.id
  }

  environment {
    id = var.environment_id
  }
}

# Service Account
resource "confluent_service_account" "app" {
  display_name = var.service_account_name
  description  = "Service account for POC application access to Kafka topics"
}

# API Key for the service account
resource "confluent_api_key" "app" {
  display_name = "${var.service_account_name}-api-key"
  description  = "API key for ${var.service_account_name}"

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.this.id
    api_version = confluent_kafka_cluster.this.api_version
    kind        = confluent_kafka_cluster.this.kind

    environment {
      id = var.environment_id
    }
  }
}

# Topics
resource "confluent_kafka_topic" "topics" {
  for_each = { for t in var.topics : t.name => t }

  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  topic_name       = each.value.name
  partitions_count = each.value.partitions
  rest_endpoint    = confluent_kafka_cluster.this.rest_endpoint

  config = each.value.config

  credentials {
    key    = confluent_api_key.app.id
    secret = confluent_api_key.app.secret
  }
}

# ACLs — Producer permissions
resource "confluent_kafka_acl" "producer" {
  for_each = { for t in var.topics : t.name => t }

  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "TOPIC"
  resource_name = each.value.name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.app.id
    secret = confluent_api_key.app.secret
  }
}

# ACLs — Consumer permissions
resource "confluent_kafka_acl" "consumer" {
  for_each = { for t in var.topics : t.name => t }

  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "TOPIC"
  resource_name = each.value.name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.app.id
    secret = confluent_api_key.app.secret
  }
}

# ACL — Consumer group read (required for consumers)
resource "confluent_kafka_acl" "consumer_group" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "GROUP"
  resource_name = var.consumer_group_prefix
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.app.id
    secret = confluent_api_key.app.secret
  }
}
