###############################################################################
# AKS Module
# Creates: AKS Cluster with workload identity, system-assigned managed identity
###############################################################################

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # Auto-patch security fixes (only z-version bumps e.g., 1.35.1 → 1.35.2)
  automatic_upgrade_channel = var.automatic_upgrade_channel

  # Auto-patch node OS security vulnerabilities (kernel, packages)
  node_os_upgrade_channel = var.node_os_upgrade_channel

  # Auto-clean stale container images from nodes
  image_cleaner_enabled        = var.image_cleaner_enabled
  image_cleaner_interval_hours = var.image_cleaner_interval_hours

  default_node_pool {
    name                         = "system"
    node_count                   = 1
    vm_size                      = var.vm_size
    vnet_subnet_id               = var.subnet_id
    os_disk_type                 = var.os_disk_type
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = var.max_surge
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable workload identity for Key Vault access
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Private cluster — API server only accessible via private IP within VNet
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_dns_zone_id
  private_cluster_public_fqdn_enabled = false

  # Restrict API server access to known IP ranges (applies only when NOT private)
  api_server_access_profile {
    authorized_ip_ranges = var.private_cluster_enabled ? [] : var.api_server_authorized_ip_ranges
  }

  # Entra ID (AAD) integration + Azure RBAC — eliminates static kubeconfig creds
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  local_account_disabled = var.local_account_disabled

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  tags = var.tags
}

# --- User Node Pool (application workloads) ---
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.vm_size
  node_count            = var.node_count
  vnet_subnet_id        = var.subnet_id
  os_disk_type          = var.os_disk_type

  node_labels = {
    "workload" = "application"
  }

  upgrade_settings {
    max_surge = var.max_surge
  }

  tags = var.tags
}
