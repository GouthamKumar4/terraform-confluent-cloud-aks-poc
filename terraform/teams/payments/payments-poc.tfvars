# Payments team configuration
# Secrets passed via TF_VAR_* environment variables:
#   TF_VAR_azure_subscription_id
# Confluent Cloud API key is read from Key Vault (scoped ResourceOwner key,
# manually created by cloud admin per Runbook Step D.2). NOT from GitHub Secrets.

team_name            = "payments"

# Key Vault resource ID (from platform deployment output)
# Format: /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<name>
key_vault_id = ""  # Set via TF_VAR_key_vault_id or pipeline variable

topics = [
  { name = "payments", partitions = 3, config = {} }
]

consumer_group_prefix = "payments-"
