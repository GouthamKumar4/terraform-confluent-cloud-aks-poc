###############################################################################
# Confluent Cloud Module
# Creates: Environment, Network (PrivateLink), Dedicated Kafka Cluster,
#          Topics, Service Account, API Key, ACLs, and Private Link Access
###############################################################################

# Environment
resource "confluent_environment" "this" {
  display_name = var.environment_name

  stream_governance {
    package = "ESSENTIALS"
  }
}

# Confluent-managed Network (THEIR side — you declare, they manage)
# This is NOT your Azure VNet. This is Confluent's internal network
# that exposes a Private Link Service for your PE to connect to.
resource "confluent_network" "this" {
  display_name     = "${var.cluster_name}-network"
  cloud            = "AZURE"
  region           = var.confluent_region
  connection_types = ["PRIVATELINK"]

  environment {
    id = confluent_environment.this.id
  }
}

# Private Link Access — grants YOUR Azure subscription permission to connect
resource "confluent_private_link_access" "this" {
  display_name = "${var.cluster_name}-pl-access"

  azure {
    subscription = var.azure_subscription_id
  }

  environment {
    id = confluent_environment.this.id
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
    id = confluent_environment.this.id
  }
}

# Service Account
resource "confluent_service_account" "app" {
  display_name = var.service_account_name
  description  = "Service account for POC application access to Kafka topics"
}

# API Key for the service account
resource "confluent_api_key" "app" {
  display_name           = "${var.service_account_name}-api-key"
  description            = "API key for ${var.service_account_name}"
  disable_wait_for_ready = true

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
      id = confluent_environment.this.id
    }
  }
}

# Role bindings — grants the service account DeveloperRead + DeveloperWrite
# scoped to each topic, satisfying "ACLs tying the key to produce/consume rights".
# Uses the Confluent Cloud management API (public), NOT the Kafka REST API,
# so it works regardless of PrivateLink restrictions.

resource "confluent_role_binding" "app_developer_read" {
  for_each = { for t in var.topics : t.name => t }

  principal   = "User:${confluent_service_account.app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.this.rbac_crn}/kafka=${confluent_kafka_cluster.this.id}/topic=${each.key}"
}

resource "confluent_role_binding" "app_developer_write" {
  for_each = { for t in var.topics : t.name => t }

  principal   = "User:${confluent_service_account.app.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.this.rbac_crn}/kafka=${confluent_kafka_cluster.this.id}/topic=${each.key}"
}

# Consumer group access — required for consumers to join groups with the configured prefix
resource "confluent_role_binding" "app_developer_read_group" {
  principal   = "User:${confluent_service_account.app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.this.rbac_crn}/kafka=${confluent_kafka_cluster.this.id}/group=${var.consumer_group_prefix}*"
}

###############################################################################
# Topics and ACLs
# NOTE: These resources use the Kafka REST API (data plane), which is only
# accessible via PrivateLink from inside the VNet. They cannot be created
# from a local machine. Create these via the Confluent Cloud UI or CLI,
# or run Terraform from a host inside the private network.
# See: https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations/dedicated-privatelink-azure-kafka-acls
###############################################################################

# resource "confluent_kafka_topic" "topics" {
#   for_each = { for t in var.topics : t.name => t }
#
#   kafka_cluster {
#     id = confluent_kafka_cluster.this.id
#   }
#
#   topic_name       = each.value.name
#   partitions_count = each.value.partitions
#   rest_endpoint    = confluent_kafka_cluster.this.rest_endpoint
#
#   config = each.value.config
#
#   credentials {
#     key    = confluent_api_key.app.id
#     secret = confluent_api_key.app.secret
#   }
# }

# resource "confluent_kafka_acl" "producer" {
#   for_each = { for t in var.topics : t.name => t }
#
#   kafka_cluster {
#     id = confluent_kafka_cluster.this.id
#   }
#
#   resource_type = "TOPIC"
#   resource_name = each.value.name
#   pattern_type  = "LITERAL"
#   principal     = "User:${confluent_service_account.app.id}"
#   host          = "*"
#   operation     = "WRITE"
#   permission    = "ALLOW"
#   rest_endpoint = confluent_kafka_cluster.this.rest_endpoint
#
#   credentials {
#     key    = confluent_api_key.app.id
#     secret = confluent_api_key.app.secret
#   }
# }

# resource "confluent_kafka_acl" "consumer" {
#   for_each = { for t in var.topics : t.name => t }
#
#   kafka_cluster {
#     id = confluent_kafka_cluster.this.id
#   }
#
#   resource_type = "TOPIC"
#   resource_name = each.value.name
#   pattern_type  = "LITERAL"
#   principal     = "User:${confluent_service_account.app.id}"
#   host          = "*"
#   operation     = "READ"
#   permission    = "ALLOW"
#   rest_endpoint = confluent_kafka_cluster.this.rest_endpoint
#
#   credentials {
#     key    = confluent_api_key.app.id
#     secret = confluent_api_key.app.secret
#   }
# }

# resource "confluent_kafka_acl" "consumer_group" {
#   kafka_cluster {
#     id = confluent_kafka_cluster.this.id
#   }
#
#   resource_type = "GROUP"
#   resource_name = var.consumer_group_prefix
#   pattern_type  = "PREFIXED"
#   principal     = "User:${confluent_service_account.app.id}"
#   host          = "*"
#   operation     = "READ"
#   permission    = "ALLOW"
#   rest_endpoint = confluent_kafka_cluster.this.rest_endpoint
#
#   credentials {
#     key    = confluent_api_key.app.id
#     secret = confluent_api_key.app.secret
#   }
# }
