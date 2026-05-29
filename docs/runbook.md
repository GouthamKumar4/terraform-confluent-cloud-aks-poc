# Runbook: Private Confluent Kafka + AKS POC

## Prerequisites & Bootstrap

> **All steps below are one-time setup BEFORE running `terraform apply`.**

### Tools Required
- Terraform >= 1.5.0 (`terraform version`)
- Azure CLI >= 2.50 (`az version`)
- kubectl (`az aks install-cli`)
- Confluent CLI (optional, for verification)

---

### Step A: Azure — Create Terraform State Backend

```bash
# Login to Azure
az login
az account set --subscription "<your-subscription-id>"

# Create resource group for TF state
az group create \
  --name tfstate-rg \
  --location westeurope

# Create storage account (must be globally unique)
# Naming: 3-24 chars, lowercase + numbers only (no hyphens/underscores allowed)
# Convention: <project-short><purpose> → e.g., "pocconfluenttfstate"
az storage account create \
  --name pocconfluenttfstate \
  --resource-group tfstate-rg \
  --location westeurope \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# Create blob container
# Convention: "tfstate" — one container per project, state files separated by key path
az storage container create \
  --name tfstate \
  --account-name pocconfluenttfstate
```

---

### Step B: Azure — Create Service Principal or Managed Identity

#### Option 1: Service Principal with OIDC (recommended for GitHub Actions)

```bash
# Create SP (note the appId and tenant)
az ad sp create-for-rbac \
  --name "sp-terraform-poc" \
  --role Contributor \
  --scopes /subscriptions/<subscription-id>

# Output:
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",    ← ARM_CLIENT_ID
#   "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",   ← ARM_TENANT_ID
#   "password": "...",                                   ← ARM_CLIENT_SECRET (only if not using OIDC)
# }

# Grant Key Vault Administrator (needed to create vaults + assign RBAC)
az role assignment create \
  --assignee <appId> \
  --role "Key Vault Administrator" \
  --scope /subscriptions/<subscription-id>

# Grant User Access Administrator (needed to assign roles to AKS identity)
az role assignment create \
  --assignee <appId> \
  --role "User Access Administrator" \
  --scope /subscriptions/<subscription-id>
```

#### Option 2: Setup OIDC Federated Credential (no client secret needed)

```bash
# Get the app object ID
APP_OBJECT_ID=$(az ad app show --id <appId> --query id -o tsv)

# Create federated credential for GitHub Actions (main branch)
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<your-org>/<your-repo>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests (optional)
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "github-actions-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<your-org>/<your-repo>:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

#### Option 3: Managed Identity (for self-hosted runners / Azure DevOps)

```bash
# Create user-assigned managed identity
az identity create \
  --name mi-terraform-poc \
  --resource-group tfstate-rg \
  --location westeurope

# Get principal ID
MI_PRINCIPAL_ID=$(az identity show --name mi-terraform-poc --resource-group tfstate-rg --query principalId -o tsv)

# Assign roles
az role assignment create --assignee $MI_PRINCIPAL_ID --role Contributor --scope /subscriptions/<subscription-id>
az role assignment create --assignee $MI_PRINCIPAL_ID --role "Key Vault Administrator" --scope /subscriptions/<subscription-id>
az role assignment create --assignee $MI_PRINCIPAL_ID --role "User Access Administrator" --scope /subscriptions/<subscription-id>
```

---

### Step C: Azure — Register Required Providers

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage

# Verify registration
az provider show --namespace Microsoft.ContainerService --query "registrationState"
```

---

### Step D: Confluent Cloud — Organization & API Key Setup

1. **Create Confluent Cloud account** (if not exists):
   - Go to https://confluent.cloud → Sign up

2. **Create a service account for Terraform** (recommended over personal credentials):
   - Confluent Console → Accounts & access → Service accounts → Add service account
   - Name: `sa-terraform-admin`
   - Description: "Terraform automation — manages environments, clusters, topics"

3. **Assign OrganizationAdmin role** to the service account:
   - Accounts & access → Role bindings → Add role binding
   - Principal: `sa-terraform-admin`
   - Role: `OrganizationAdmin`
   - This allows Terraform to create environments, networks, clusters, service accounts, API keys, topics, ACLs

4. **Generate Cloud API key** for the service account:
   - Confluent Console → API keys → Add key → Cloud resource management
   - Select: Service account `sa-terraform-admin`
   - **Save both Key and Secret** — the secret is shown only once!
   - These become `TF_VAR_confluent_cloud_api_key` and `TF_VAR_confluent_cloud_api_secret`

5. **(Optional) Create user groups** for team access:
   - Accounts & access → Groups → Add group
   - Assign roles per environment/cluster after Terraform creates them

---

### Step E: GitHub — Configure Repository Secrets

Go to GitHub → Repository → Settings → Secrets and variables → Actions → New repository secret:

| Secret Name | Value | Source |
|-------------|-------|--------|
| `ARM_CLIENT_ID` | Service principal appId | Step B output |
| `ARM_TENANT_ID` | Azure tenant ID | Step B output |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID | `az account show --query id` |
| `ARM_CLIENT_SECRET` | SP password (skip if OIDC) | Step B output |
| `CONFLUENT_CLOUD_API_KEY` | Confluent Cloud API key | Step D output |
| `CONFLUENT_CLOUD_API_SECRET` | Confluent Cloud API secret | Step D output |

If using OIDC, also add `ARM_USE_OIDC=true` as a repository variable (not secret).

---

### Step F: Azure DevOps — Alternative Setup (if not using GitHub)

1. Create a service connection (type: Azure Resource Manager → Workload Identity federation)
2. Add variable group with:
   - `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` (from service connection)
   - `CONFLUENT_CLOUD_API_KEY`, `CONFLUENT_CLOUD_API_SECRET` (as secrets)
3. Pipeline uses `AzureCLI@2` task which auto-sets `ARM_*` env vars

---

## Execution Steps

### Step 1: Configure Variables
```bash
cd terraform/environments/poc
```

Non-sensitive values are already in `poc.tfvars` (committed to repo).

Set sensitive variables via environment:
```bash
export TF_VAR_confluent_cloud_api_key="<your-confluent-api-key>"
export TF_VAR_confluent_cloud_api_secret="<your-confluent-api-secret>"
export TF_VAR_azure_subscription_id="<your-subscription-id>"
```

### Step 2: Initialize Terraform
```bash
terraform init
```
Expected: Backend configured, providers downloaded.

### Step 3: Plan
```bash
terraform plan -var-file=poc.tfvars -out=tfplan
```
Expected: ~20-25 resources to create. Review plan for correctness.

### Step 4: Apply
```bash
terraform apply tfplan
```
Expected: All resources created. Note outputs.

### Step 5: Accept Private Link Connection (if manual)
In some setups, the Private Link connection needs approval on the Confluent side:
- Check Confluent Console → Networking → Private Link
- Or wait for auto-approval if configured

---

## Verification Steps

### V1: Confluent Resources
```bash
# List environment
terraform output confluent_environment_id

# List cluster
terraform output confluent_cluster_id

# List topics
terraform output confluent_topic_names
```

### V2: Private Endpoint
```bash
# Resource names follow Azure CAF naming convention
# Use terraform output to get actual names
RG_NAME=$(terraform output -raw resource_group_name)

az network private-endpoint list \
  --resource-group $RG_NAME \
  --query "[].{name:name, status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
  -o table
```
Expected: Status = `Approved`

### V3: AKS Cluster
```bash
AKS_NAME=$(terraform output -raw aks_cluster_name)
RG_NAME=$(terraform output -raw resource_group_name)

# Private cluster — use 'command invoke' (relays via ARM API, no VNet access needed)
az aks command invoke \
  --resource-group $RG_NAME \
  --name $AKS_NAME \
  --command "kubectl get nodes"
```
Expected: 2 nodes in Ready state.

> **Note:** This cluster is private (`private_cluster_enabled = true`). Direct `kubectl` requires VNet access (VPN/Bastion). For POC, use `az aks command invoke` which tunnels through ARM.

### V4: Key Vault Secrets
```bash
KV_URI=$(terraform output -raw keyvault_uri)

az keyvault secret list --id $KV_URI --query "[].name" -o tsv
```
Expected: `confluent-api-key-id`, `confluent-api-key-secret`, `kafka-bootstrap-endpoint`

### V5: Produce/Consume Test (from AKS pod)
```bash
# Deploy a test pod with kafka tools (via command invoke)
az aks command invoke \
  --resource-group $RG_NAME \
  --name $AKS_NAME \
  --command "kubectl run kafka-test --image=confluentinc/cp-kafka:latest --command -- sleep 3600"

# Exec into pod and produce a message
az aks command invoke \
  --resource-group $RG_NAME \
  --name $AKS_NAME \
  --command "kubectl exec kafka-test -- kafka-console-producer --broker-list <bootstrap-endpoint>:9092 \
    --producer-property security.protocol=SASL_SSL \
    --producer-property sasl.mechanism=PLAIN \
    --producer-property 'sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"<api-key-id>\" password=\"<api-key-secret>\";' \
    --topic orders <<< 'hello-kafka'"

# Consume the message
az aks command invoke \
  --resource-group $RG_NAME \
  --name $AKS_NAME \
  --command "kubectl exec kafka-test -- kafka-console-consumer --bootstrap-server <bootstrap-endpoint>:9092 \
    --consumer-property security.protocol=SASL_SSL \
    --consumer-property sasl.mechanism=PLAIN \
    --consumer-property 'sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"<api-key-id>\" password=\"<api-key-secret>\";' \
    --topic orders --from-beginning --max-messages 1"
```

### V6: Negative Test (unauthorized)
Use a different/invalid API key and confirm connection is refused.

---

## Cleanup
```bash
cd terraform/environments/poc
terraform destroy -var-file=poc.tfvars
```

---

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| Private endpoint stuck in "Pending" | Check Confluent Console → approve connection |
| DNS resolution fails from AKS | Verify private DNS zone is linked to VNet |
| Key Vault access denied | Check RBAC role assignment for AKS identity |
| Confluent API key fails | Ensure key is cluster-scoped, not org-scoped |
| Terraform state lock | Run `terraform force-unlock <LOCK_ID>` |
