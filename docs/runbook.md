# Runbook: Private Confluent Kafka + AKS POC

This runbook intentionally treats Azure state/identity setup and Confluent Cloud administrator setup as **manual prerequisites**. Terraform in this repository is for the workload POC only: private Confluent Cloud Kafka in an existing environment, topics, application service account/API key/ACLs, Azure PrivateLink networking, AKS, and Key Vault.

## Prerequisites

- Terraform >= 1.5.0 (`terraform version`)
- Azure CLI >= 2.50 (`az version`)
- Azure permission to create a resource group, storage account, managed identity, and RBAC assignments in the target subscription
- Confluent Cloud organization access
- Optional: `kubectl` and Confluent CLI for verification

---

## Phase 1 — Manually Create Azure Prerequisites

Create these resources with Azure CLI before running Terraform:

- Resource group for Terraform state and deployment identity
- Azure Storage account and private blob container for Terraform remote state
- User-assigned managed identity for Terraform deployment
- RBAC assignments for the managed identity

### Step 1: Set variables and login

```bash
SUBSCRIPTION_ID="<your-subscription-id>"
LOCATION="westeurope"
TFSTATE_RG="rg-tfstate-poc-001"
TFSTATE_SA="<globally-unique-storage-account>"
TFSTATE_CONTAINER="tfstate"
MI_NAME="mi-terraform-poc-001"

az login
az account set --subscription "$SUBSCRIPTION_ID"
```

### Step 2: Create Terraform state storage

```bash
az group create \
  --name "$TFSTATE_RG" \
  --location "$LOCATION"

az storage account create \
  --name "$TFSTATE_SA" \
  --resource-group "$TFSTATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az storage container create \
  --name "$TFSTATE_CONTAINER" \
  --account-name "$TFSTATE_SA" \
  --auth-mode login
```

Optional hardening after state backend access is confirmed:

```bash
az storage account blob-service-properties update \
  --account-name "$TFSTATE_SA" \
  --resource-group "$TFSTATE_RG" \
  --enable-versioning true \
  --delete-retention-days 14 \
  --container-delete-retention-days 14
```

### Step 3: Create Terraform deployment managed identity

```bash
az identity create \
  --name "$MI_NAME" \
  --resource-group "$TFSTATE_RG" \
  --location "$LOCATION"

MI_PRINCIPAL_ID=$(az identity show \
  --name "$MI_NAME" \
  --resource-group "$TFSTATE_RG" \
  --query principalId -o tsv)

MI_CLIENT_ID=$(az identity show \
  --name "$MI_NAME" \
  --resource-group "$TFSTATE_RG" \
  --query clientId -o tsv)
```

### Step 4: Assign Azure RBAC to the managed identity

```bash
az role assignment create \
  --assignee "$MI_PRINCIPAL_ID" \
  --role Contributor \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment create \
  --assignee "$MI_PRINCIPAL_ID" \
  --role "Key Vault Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment create \
  --assignee "$MI_PRINCIPAL_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

TFSTATE_SCOPE=$(az storage account show \
  --name "$TFSTATE_SA" \
  --resource-group "$TFSTATE_RG" \
  --query id -o tsv)

az role assignment create \
  --assignee "$MI_PRINCIPAL_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$TFSTATE_SCOPE"
```

### Step 5: Create local backend config

```bash
cd terraform/environments/poc
cp backend.hcl.example backend.hcl
```

Update `backend.hcl` with the manually-created storage values:

```hcl
resource_group_name  = "rg-tfstate-poc-001"
storage_account_name = "<globally-unique-storage-account>"
container_name       = "tfstate"
key                  = "poc/confluent-kafka/poc.tfstate"
use_azuread_auth     = true
```

---

## Phase 2 — Manually Create Confluent Cloud Admin Prerequisites

Do this in the Confluent Cloud UI or with the Confluent CLI. This repository does **not** provision your Confluent Cloud account/login or Terraform admin identity.

1. Open Confluent Cloud service accounts: <https://confluent.cloud/settings/org/accounts/service-accounts>
2. Create or choose a Terraform administration service account, for example `sa-terraform-admin`.
3. Create or choose the Confluent Cloud environment for the POC and capture its environment ID, for example `env-abc123`.
4. Grant the Terraform admin service account the organization/environment permissions required to create private networking, clusters, app service accounts, API keys, topics, and ACLs for this POC.
5. Create a **Cloud resource management** API key for that Terraform admin service account.
6. Save the key and secret; the secret is shown only once.

Export those credentials before planning the workload:

```bash
export TF_VAR_confluent_cloud_api_key="<confluent-cloud-api-key>"
export TF_VAR_confluent_cloud_api_secret="<confluent-cloud-api-secret>"
export TF_VAR_confluent_environment_id="<existing-confluent-environment-id>"
```

---

## Phase 3 — Register Azure Resource Providers

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
```

Verify registration:

```bash
az provider show --namespace Microsoft.ContainerService --query "registrationState"
az provider show --namespace Microsoft.ManagedIdentity --query "registrationState"
```

---

## Phase 4 — Authenticate Terraform with the Managed Identity

Run Terraform from a VM/runner that has the user-assigned managed identity attached, then login with that identity:

```bash
az login --identity --client-id "$MI_CLIENT_ID"
export ARM_USE_MSI=true
export ARM_CLIENT_ID="$MI_CLIENT_ID"
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
```

If you use a different CI authentication pattern, keep the same principle: Azure authentication is a prerequisite and is not provisioned by this workload Terraform.

---

## Phase 5 — Deploy Workload

### Step 1: Configure workload variables

```bash
cd terraform/environments/poc
```

Non-sensitive defaults are committed in `poc.tfvars`, including:

- Confluent region: `westeurope`
- Two topics: `orders`, `payments`
- AKS private cluster enabled
- VNet: `10.0.0.0/16`

Set sensitive and subscription variables:

```bash
export TF_VAR_confluent_cloud_api_key="<confluent-cloud-api-key>"
export TF_VAR_confluent_cloud_api_secret="<confluent-cloud-api-secret>"
export TF_VAR_confluent_environment_id="<existing-confluent-environment-id>"
export TF_VAR_azure_subscription_id="$SUBSCRIPTION_ID"
```

### Step 2: Initialize Terraform with the manually-created remote backend

```bash
terraform init -backend-config=backend.hcl
```

Expected result: Terraform configures the AzureRM backend and downloads providers.

### Step 3: Plan

```bash
terraform plan -var-file=poc.tfvars -out=tfplan
```

Expected result: Terraform plans the Confluent private networking/cluster in the existing environment, application service account, API key, ACLs, two topics, Azure VNet/private endpoint/private DNS, AKS, Log Analytics, and Key Vault resources.

### Step 4: Apply

```bash
terraform apply tfplan
```

Expected result: all POC workload resources are created and outputs are available.

### Step 5: Approve or confirm PrivateLink connection

Depending on Confluent Cloud behavior for the network, the private endpoint connection may require approval/confirmation:

- Confluent Console → Networking → Private Link
- Azure Portal → Private endpoint connection status

---

## Verification Steps

### V1: Terraform outputs

```bash
terraform output resource_group_name
terraform output confluent_environment_id
terraform output confluent_cluster_id
terraform output confluent_topic_names
terraform output aks_cluster_name
```

Expected result: `confluent_topic_names` includes `orders` and `payments`.

### V2: Azure Private Endpoint

```bash
RG_NAME=$(terraform output -raw resource_group_name)

az network private-endpoint list \
  --resource-group "$RG_NAME" \
  --query "[].{name:name, status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status, ip:customDnsConfigs[0].ipAddresses[0]}" \
  -o table
```

Expected result: status is `Approved` and the private endpoint has a private IP.

### V3: Key Vault secrets

```bash
terraform output -json keyvault_secret_uris
```

Expected result: versionless secret URIs exist for:

- `confluent-api-key-id`
- `confluent-api-key-secret`
- `kafka-bootstrap-endpoint`

### V4: AKS access

For a private AKS cluster, run this from a host that can resolve/reach the private API server in the VNet:

```bash
RG_NAME=$(terraform output -raw resource_group_name)
AKS_NAME=$(terraform output -raw aks_cluster_name)

az aks get-credentials --resource-group "$RG_NAME" --name "$AKS_NAME"
kubectl get nodes
```

### V5: Kafka private DNS from inside the VNet

Run from a VM/pod inside the VNet:

```bash
BOOTSTRAP=$(az keyvault secret show \
  --vault-name "<key-vault-name>" \
  --name kafka-bootstrap-endpoint \
  --query value -o tsv)

nslookup "${BOOTSTRAP#SASL_SSL://}"
```

Expected result: the bootstrap hostname resolves to the Azure private endpoint IP.

---

## Cleanup

Destroy the workload with Terraform:

```bash
cd terraform/environments/poc
terraform destroy -var-file=poc.tfvars
```

After confirming no state is needed, manually remove the prerequisite resources if desired:

```bash
az identity delete --name "$MI_NAME" --resource-group "$TFSTATE_RG"
az storage account delete --name "$TFSTATE_SA" --resource-group "$TFSTATE_RG"
az group delete --name "$TFSTATE_RG"
```
