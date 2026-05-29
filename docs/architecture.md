# Architecture

## Scope

This POC provisions workload infrastructure with Terraform while keeping prerequisite/admin setup manual:

- **Manual prerequisites**: Azure Terraform state storage, deployment managed identity, RBAC assignments, and Confluent Cloud Terraform admin service account/API key are created outside this Terraform code by Azure CLI, Confluent CLI, or UI.
- **Terraform workload**: Confluent Cloud private Kafka resources in an existing environment, Azure PrivateLink networking, two Kafka topics (`orders`, `payments`), one application service account, one Kafka API key, ACLs, AKS, and Key Vault.

## Components

### Manual Azure Prerequisites

- **State resource group**: holds the state storage account and deployment managed identity.
- **Storage account/container**: AzureRM backend for Terraform state; created manually with Azure CLI.
- **User-assigned managed identity**: attached to the runner/VM that executes Terraform.
- **RBAC assignments**: manually granted to the managed identity, including Contributor, Key Vault Administrator, User Access Administrator, and Storage Blob Data Contributor for state access.

### Manual Confluent Cloud Admin Prerequisites

- **Confluent Cloud account/login**: handled outside Terraform.
- **Terraform admin service account/API key**: created through Confluent UI or CLI and exported as `TF_VAR_confluent_cloud_api_key` and `TF_VAR_confluent_cloud_api_secret`.

### Confluent Cloud Workload

- **Environment**: logical grouping for the POC resources.
- **Network**: Confluent-managed Azure PrivateLink network.
- **Private Link Access**: allows the Azure subscription to connect to the Confluent PrivateLink service.
- **Kafka Cluster**: Dedicated tier, single-zone, 1 CKU by default for POC cost control.
- **Topics**: `orders` and `payments`, 3 partitions each by default.
- **Application Service Account**: single application principal for the POC workload.
- **Kafka API Key**: API key owned by the application service account.
- **ACLs**: `WRITE` and `READ` on each topic, plus `READ` on the configured consumer group prefix.

### Azure Networking Workload

- **Virtual Network**: `10.0.0.0/16` by default.
- **Private Endpoint Subnet**: `10.0.1.0/24`; hosts the Azure private endpoint to Confluent.
- **AKS Subnet**: `10.0.4.0/22`; hosts AKS node pools.
- **Private DNS Zone**: created from Confluent's DNS domain output so Kafka names resolve privately inside the VNet.
- **Network Security Groups**: associated with both POC subnets.

### Azure Kubernetes Service Workload

- **Cluster**: Azure CNI, Calico network policy, private API server by default.
- **System node pool**: one system node pool for critical add-ons.
- **User node pool**: configurable POC application node pool.
- **Identity**: system-assigned cluster identity with OIDC issuer and workload identity enabled.

### Azure Key Vault Workload

- **Vault**: standard SKU, purge protection, soft delete, RBAC authorization.
- **Secrets**:
  - `confluent-api-key-id`
  - `confluent-api-key-secret`
  - `kafka-bootstrap-endpoint`
- **Access**: the AKS kubelet identity receives `Key Vault Secrets User`; the Terraform deployment principal receives `Key Vault Secrets Officer` to write generated secrets.

## Data Flow

1. An operator manually creates Azure state storage, the deployment managed identity, and RBAC assignments with Azure CLI.
2. An operator manually creates the Confluent Cloud Terraform admin service account/API key with Confluent UI or CLI.
3. Terraform runs from a host authenticated as the managed identity and uses the manually-created Azure Storage backend.
4. Terraform authenticates to Confluent Cloud with the manually-created Terraform admin API key.
5. Terraform creates the Confluent private networking, Kafka cluster in the existing environment, application service account, Kafka API key, topics, and ACLs.
6. Terraform creates the Azure VNet, private endpoint, and private DNS record that point workload traffic to the Confluent PrivateLink service.
7. Terraform creates AKS, Key Vault, and stores the generated Kafka bootstrap endpoint/API credentials as Key Vault secrets.
8. Workloads running on AKS resolve Kafka through private DNS and connect over the private endpoint path.

## Network Security

- Kafka is designed to be reached through PrivateLink from the Azure VNet path, not as a public connectivity POC.
- AKS private cluster mode is enabled by default, so the Kubernetes API server is reachable only from private network paths.
- Key Vault has RBAC authorization enabled and denies network traffic by default unless allowed by configuration/Azure service bypass.
- Terraform state is centralized in manually-created Azure Blob Storage instead of local files.

## Non-Goals

- Terraform-managed creation of Azure state storage, managed identity, or RBAC.
- Terraform-managed Confluent Cloud account login or Terraform admin identity creation.
- Production-grade HA and multi-region failover.
- Performance testing or long-running load tests.
