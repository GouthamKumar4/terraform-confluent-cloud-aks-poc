# Private Confluent Cloud Kafka + AKS — Terraform POC

## Overview

This repository provisions the requested workload POC with Terraform after the platform prerequisites are created manually:

1. **Manual Azure prerequisites**: create the Terraform state storage account/container, a deployment managed identity, and its Azure RBAC assignments with Azure CLI.
2. **Manual Confluent prerequisites**: create/login to the Confluent Cloud organization and create the Terraform admin service account/API key through the UI or Confluent CLI.
3. **Terraform workload**: reference an existing Confluent Cloud environment and provision private Kafka networking/cluster resources, two topics (`orders`, `payments`), one application service account, one Kafka API key, ACLs for the topics, Azure PrivateLink networking, AKS, Log Analytics, and Key Vault.

Generated Kafka credentials are stored in Azure Key Vault. Local backend configuration and secrets are not committed.

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│ Azure Subscription                                              │
│                                                                │
│  Manual prerequisites                                           │
│  ┌──────────────────────┐       ┌──────────────────────────┐   │
│  │ User-assigned MI     │──────►│ Storage account + tfstate │   │
│  │ created by az CLI    │       │ created by az CLI         │   │
│  └──────────────────────┘       └──────────────────────────┘   │
│                                                                │
│  Terraform workload                                             │
│  ┌──────────────┐    PrivateLink     ┌────────────────────┐    │
│  │  VNet        │◄──────────────────►│ Confluent Cloud     │    │
│  │  ├─ PE Subnet│                    │ Private Kafka       │    │
│  │  └─ AKS Sub  │                    │ orders/payments     │    │
│  └──────┬───────┘                    └────────────────────┘    │
│         │                                                      │
│  ┌──────▼───────┐         ┌────────────────┐                  │
│  │  AKS Cluster │────────►│  Key Vault     │                  │
│  │  workload    │  reads  │  Kafka API key │                  │
│  │  identity    │         │  + endpoint    │                  │
│  └──────────────┘         └────────────────┘                  │
└────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
terraform/
├── environments/poc/      # Root module for the Confluent + AKS POC
└── modules/
    ├── confluent/         # Kafka cluster, topics, service account, API key, ACLs
    ├── networking/        # VNet, Private Endpoint, private DNS
    ├── aks/               # AKS cluster
    └── keyvault/          # Secret storage
docs/                      # Architecture, runbook, presentation material
```

## Prerequisites

- Terraform >= 1.5
- Azure CLI authenticated (`az login`)
- Azure subscription permissions to create the state backend, managed identity, and RBAC assignments
- Confluent Cloud organization access and a manually-created Terraform admin Cloud API key

## Quick Start

### 1. Manually create Azure prerequisites

Create the Terraform state backend and managed identity with Azure CLI before running Terraform:

```bash
SUBSCRIPTION_ID="<your-subscription-id>"
LOCATION="westeurope"
TFSTATE_RG="rg-tfstate-poc-001"
TFSTATE_SA="<globally-unique-storage-account>"
TFSTATE_CONTAINER="tfstate"
MI_NAME="mi-terraform-poc-001"

az login
az account set --subscription "$SUBSCRIPTION_ID"
az group create --name "$TFSTATE_RG" --location "$LOCATION"
az storage account create \
  --name "$TFSTATE_SA" \
  --resource-group "$TFSTATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false
az storage container create --name "$TFSTATE_CONTAINER" --account-name "$TFSTATE_SA" --auth-mode login
az identity create --name "$MI_NAME" --resource-group "$TFSTATE_RG" --location "$LOCATION"

MI_PRINCIPAL_ID=$(az identity show --name "$MI_NAME" --resource-group "$TFSTATE_RG" --query principalId -o tsv)
MI_CLIENT_ID=$(az identity show --name "$MI_NAME" --resource-group "$TFSTATE_RG" --query clientId -o tsv)
az role assignment create --assignee "$MI_PRINCIPAL_ID" --role Contributor --scope "/subscriptions/$SUBSCRIPTION_ID"
az role assignment create --assignee "$MI_PRINCIPAL_ID" --role "Key Vault Administrator" --scope "/subscriptions/$SUBSCRIPTION_ID"
az role assignment create --assignee "$MI_PRINCIPAL_ID" --role "User Access Administrator" --scope "/subscriptions/$SUBSCRIPTION_ID"
az role assignment create --assignee "$MI_PRINCIPAL_ID" --role "Storage Blob Data Contributor" --scope "$(az storage account show --name "$TFSTATE_SA" --resource-group "$TFSTATE_RG" --query id -o tsv)"
```

Create `terraform/environments/poc/backend.hcl` from `terraform/environments/poc/backend.hcl.example` and set the storage account name.

### 2. Manually create Confluent admin prerequisites

In Confluent Cloud UI or CLI, create/login to the organization, create or choose the POC environment, and create a Terraform admin service account plus Cloud API key. Use the service accounts page if using the UI:

<https://confluent.cloud/settings/org/accounts/service-accounts>

Export the Confluent Cloud key/secret for Terraform:

```bash
export TF_VAR_confluent_cloud_api_key="<your-confluent-cloud-api-key>"
export TF_VAR_confluent_cloud_api_secret="<your-confluent-cloud-api-secret>"
export TF_VAR_confluent_environment_id="<existing-confluent-environment-id>"
```

### 3. Deploy the POC workload

Authenticate to Azure as the managed identity from an Azure-hosted runner/VM assigned to that MI:

```bash
az login --identity --client-id "$MI_CLIENT_ID"
export ARM_USE_MSI=true
export ARM_CLIENT_ID="$MI_CLIENT_ID"
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
```

Then deploy:

```bash
cd terraform/environments/poc
export TF_VAR_azure_subscription_id="$SUBSCRIPTION_ID"
terraform init -backend-config=backend.hcl
terraform plan -var-file=poc.tfvars -out=tfplan
terraform apply tfplan
```

## Cleanup

Destroy the workload with Terraform. Delete the manually-created state backend and managed identity only after you no longer need the state file.

```bash
cd terraform/environments/poc
terraform destroy -var-file=poc.tfvars
```

## Documentation

- [Architecture](docs/architecture.md)
- [Runbook](docs/runbook.md)
- [Presentation](docs/presentation.md) — export to PPTX: `marp docs/presentation.md --pptx`
- [Executive Summary](docs/executive-summary.md)

## Security

- Azure state storage, managed identity, and RBAC are explicit manual prerequisites, not Terraform-managed prerequisite resources.
- Terraform deployment uses an Azure user-assigned managed identity instead of a long-lived Azure client secret.
- Terraform state is stored in an encrypted Azure Storage account.
- Kafka access is via Azure PrivateLink/private DNS rather than public bootstrap access.
- API keys are stored in Azure Key Vault with RBAC.
- AKS uses workload identity for Key Vault access.
- No secrets are committed to source control.
