###############################################################################
# Confluent Cloud Module — Platform Only
# Creates: Environment, Network (PrivateLink), Dedicated Kafka Cluster,
#          and Private Link Access
#
# NOTE: Service accounts, API keys, topics, and ACLs are managed by the
# app team deployments in terraform/teams/<team>/ using the confluent-app module.
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
