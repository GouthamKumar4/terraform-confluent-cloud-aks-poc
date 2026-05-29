# POC environment configuration (non-sensitive values only)
# Secrets are passed via TF_VAR_* environment variables:
#   TF_VAR_confluent_cloud_api_key
#   TF_VAR_confluent_cloud_api_secret
#   TF_VAR_azure_subscription_id

# --- Naming ---
environment_short = "poc"
unique_suffix     = "001"

# --- General ---
location = "westeurope"

# --- Confluent ---
confluent_region    = "westeurope"
confluent_cku_count = 1

topics = [
  { name = "orders", partitions = 3, config = {} },
  { name = "payments", partitions = 3, config = {} }
]

# --- Networking ---
vnet_address_space = ["10.0.0.0/16"]
pe_subnet_prefix   = "10.0.1.0/24"
aks_subnet_prefix  = "10.0.4.0/22"

# --- AKS ---
kubernetes_version = "1.29"
aks_node_count     = 2
aks_vm_size        = "Standard_D2s_v5"

# --- AKS Security ---
# Private cluster — API server only accessible from within VNet
aks_private_cluster_enabled = true

# Authorized IPs (only applies if private cluster is disabled)
aks_authorized_ip_ranges = []

# Entra ID group(s) that get cluster-admin — create group in Azure portal first
# az ad group create --display-name "AKS-POC-Admins" --mail-nickname "aks-poc-admins"
aks_admin_group_object_ids = []

# --- Key Vault ---
keyvault_allowed_ips = []
