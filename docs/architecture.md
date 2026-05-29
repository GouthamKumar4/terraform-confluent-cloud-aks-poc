# Architecture
<img width="700" height="337" alt="image" src="https://github.com/user-attachments/assets/2a64e08f-a3bd-4eb6-b112-b57575a233bc" />

## Components

### Confluent Cloud
- **Environment**: Logical grouping for the POC resources
- **Kafka Cluster**: Dedicated tier (required for PrivateLink), single-zone, 1 CKU
- **Topics**: `orders` and `payments` (3 partitions each)
- **Service Account**: Single identity for application access
- **API Key**: Credentials bound to the service account
- **ACLs**: WRITE on both topics, READ on both topics, READ on consumer group prefix

### Azure Networking
- **Virtual Network**: 10.0.0.0/16
- **Private Endpoint Subnet**: 10.0.1.0/24 — hosts the PrivateLink endpoint to Confluent
- **AKS Subnet**: 10.0.4.0/22 — hosts AKS node pool
- **Private DNS Zone**: `privatelink.confluent.cloud` — resolves cluster FQDN to private IP
- **Network Security Groups**: Applied to both subnets

### Azure Kubernetes Service
- **Cluster**: Azure CNI, Calico network policy, workload identity enabled
- **Node Pool**: 2x Standard_D2s_v5 (minimal for POC)
- **Identity**: System-assigned managed identity + OIDC issuer for workload identity

### Azure Key Vault
- **Vault**: Standard SKU, RBAC-based access, purge protection enabled
- **Secrets**: Confluent API key ID, API key secret, bootstrap endpoint
- **Access**: AKS kubelet identity gets Key Vault Secrets User role

## Data Flow

1. Terraform provisions all resources in dependency order
2. Confluent cluster comes up with PrivateLink network
3. Azure Private Endpoint connects to Confluent's Private Link service
4. Private DNS zone resolves cluster FQDN → private endpoint IP
5. AKS pods resolve Kafka bootstrap via private DNS
6. AKS pods read credentials from Key Vault via workload identity
7. Pods produce/consume to Kafka over private network path

## Network Security

- Kafka cluster has no public endpoint
- All traffic from AKS to Kafka stays within Azure backbone + PrivateLink
- Key Vault uses network ACL (deny by default) + RBAC
- NSGs restrict subnet-level traffic
