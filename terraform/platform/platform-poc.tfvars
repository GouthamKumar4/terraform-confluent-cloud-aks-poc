# Platform deployment configuration (non-sensitive values only)
# Secrets are passed via TF_VAR_* environment variables:
#   TF_VAR_confluent_cloud_api_key
#   TF_VAR_confluent_cloud_api_secret
#   TF_VAR_azure_subscription_id

# --- Naming ---
team_name         = "unpr"
environment_short = "poc"
unique_suffix     = "001"

# --- General ---
location = "westeurope"

# --- Confluent ---
confluent_region    = "westeurope"
confluent_cku_count = 1

# --- Networking ---
vnet_address_space = ["10.0.0.0/22"]
pe_subnet_prefix   = "10.0.0.0/26"
aks_subnet_prefix  = "10.0.1.0/24"

# --- AKS ---
kubernetes_version = "1.35"
aks_node_count     = 2
aks_vm_size        = "Standard_D2s_v5"

# --- AKS Security ---
aks_private_cluster_enabled = true
aks_authorized_ip_ranges    = []
aks_admin_group_object_ids  = []

# --- Key Vault ---
keyvault_allowed_ips = []
