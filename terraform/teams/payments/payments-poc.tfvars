# Payments team configuration
# Secrets passed via TF_VAR_* environment variables:
#   TF_VAR_confluent_cloud_api_key
#   TF_VAR_confluent_cloud_api_secret
#   TF_VAR_azure_subscription_id

team_name            = "payments"
service_account_name = "sa-app-payments-poc-001"

# Key Vault resource ID (from platform deployment output)
# Format: /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<name>
key_vault_id = ""  # Set via TF_VAR_key_vault_id or pipeline variable

topics = [
  { name = "payments", partitions = 3, config = {} }
]

consumer_group_prefix = "payments-"
