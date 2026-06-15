# Terraform Module Reference

> Technical reference for all Terraform modules used in this POC.

---

## Module Dependency Graph

```mermaid
graph TD
    subgraph Platform["Platform Deployment (terraform/platform/)"]
        Root["Root Module<br>platform/"]
        RG["azurerm_resource_group.this"]
        LOG["azurerm_log_analytics_workspace.this"]
        
        Root --> RG
        Root --> LOG
        Root --> CM["confluent module"]
        Root --> NM["networking module"]
        Root --> AKS["aks module"]
        Root --> KV["keyvault module"]
        
        CM -->|private_link_service_aliases<br>dns_domain| NM
        CM -->|cluster_id, env_id<br>rest_endpoint, bootstrap| KV
        NM -->|aks_subnet_id| AKS
        AKS -->|kubelet_identity_object_id| KV
        RG -->|resource_group_name| NM
        RG -->|resource_group_name| AKS
        RG -->|resource_group_name| KV
        LOG -->|workspace_id| AKS
    end

    subgraph AppTeam["App Team Deployment (terraform/teams/team/)"]
        AppRoot["Root Module<br>teams/orders/"]
        KVRead["data.azurerm_key_vault_secret<br>(cluster_id, env_id, rest_endpoint)"]
        AppMod["confluent-app module<br>(topics + ACLs only)"]
        
        AppRoot --> KVRead
        KVRead -->|values| AppMod
    end

    KV -.->|"Key Vault secrets<br>(integration point)"| KVRead
    
    style Root fill:#4472C4,color:#fff
    style CM fill:#ED7D31,color:#fff
    style NM fill:#70AD47,color:#fff
    style AKS fill:#7030A0,color:#fff
    style KV fill:#FFC000,color:#000
    style AppRoot fill:#4472C4,color:#fff
    style AppMod fill:#ED7D31,color:#fff
```

### Execution Order

The architecture is split into two independent Terraform deployments (see [ADR-009](../02-design/decisions/009-monorepo-platform-teams-split.md)):

**Platform deployment** (runs on GitHub-hosted runner — management API is public):
1. **Resource Group** + **Log Analytics** (Azure infrastructure base)
2. **Confluent Module** (environment → network → PL access → cluster)
3. **Networking Module** (VNet → subnets → NSGs → PE → DNS) — depends on Confluent's PrivateLink aliases
4. **AKS Module** (cluster → node pools) — depends on networking subnet
5. **Key Vault Module** (vault → RBAC → secrets) — depends on Confluent outputs + AKS identity

**App team deployment** (runs on self-hosted runner in VNet — data plane requires PrivateLink):
1. **Read Key Vault** secrets (cluster_id, environment_id, rest_endpoint)
2. **Confluent-App Module** (SA → API key → topics → ACLs via data plane)
3. **Write Key Vault** secrets (api-key-id, api-key-secret for AKS pods)

---

## Module: `confluent`

**Path:** `terraform/modules/confluent/`
**Purpose:** Provisions Confluent Cloud platform infrastructure (environment, network, cluster). Management API only — no data plane resources.

### Resources Created (in dependency order)

| # | Resource | Type | Purpose |
|---|----------|------|---------|
| 1 | `confluent_environment.this` | Environment | Logical grouping (stream governance: ESSENTIALS) |
| 2 | `confluent_network.this` | Network | PRIVATELINK network in target region + AZs |
| 3 | `confluent_private_link_access.this` | PL Access | Grants your Azure subscription access |
| 4 | `confluent_kafka_cluster.this` | Cluster | Dedicated, single-zone, N CKUs |


### Key Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `environment_name` | string | Display name for the environment |
| `cluster_name` | string | Display name for the Kafka cluster |
| `confluent_region` | string | Cloud region (e.g., `westeurope`) |
| `cku_count` | number | Dedicated cluster units (default: 1) |
| `azure_subscription_id` | string | Your subscription — allowed through PrivateLink |

### Key Outputs

| Output | Sensitive | Description |
|--------|:---------:|-------------|
| `environment_id` | No | Confluent environment ID |
| `cluster_id` | No | Kafka cluster ID |
| `cluster_bootstrap_endpoint` | **Yes** | Bootstrap server address |
| `cluster_rest_endpoint` | **Yes** | Kafka REST endpoint (data plane URL) |
| `private_link_service_aliases` | No | Map of zone → PLS alias (consumed by networking) |
| `confluent_dns_domain` | No | DNS domain for private DNS zone |

---

## Module: `confluent-app`

**Path:** `terraform/modules/confluent-app/`
**Purpose:** Provisions per-team Kafka resources (SA, API key, topics, ACLs). Uses the Kafka data plane API — must run from inside the VNet.

### Resources Created (in dependency order)

| # | Resource | Type | Purpose |
|---|----------|------|---------|
| 1 | `confluent_kafka_topic.this` | Topics | One per entry in `var.topics` |
| 2 | `confluent_kafka_acl.producer` | ACL | WRITE per topic |
| 3 | `confluent_kafka_acl.consumer` | ACL | READ per topic |
| 4 | `confluent_kafka_acl.consumer_group` | ACL | READ on consumer group prefix |

> **Note:** Service accounts and cluster API keys are NOT created by this module. They are pre-created by the cloud admin (Runbook Step D.2) and passed as `TF_VAR_*` inputs via GitHub Environment secrets.

### Key Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `team_name` | string | Team name (used for topic prefix validation) |
| `runtime_service_account_id` | string | Runtime SA ID (from GitHub Environment, created by admin) |
| `runtime_api_key_id` | string | Cluster API key for runtime SA (from GitHub Environment) |
| `runtime_api_key_secret` | string | Cluster API secret for runtime SA (from GitHub Environment) |
| `cluster_id` | string | Kafka cluster ID (from Key Vault) |
| `environment_id` | string | Confluent environment ID (from Key Vault) |
| `rest_endpoint` | string | Kafka REST endpoint (from Key Vault) |
| `topics` | list(object) | Topics to create (name, partitions, config) |
| `consumer_group_prefix` | string | ACL prefix for consumer groups |

### Key Outputs

| Output | Sensitive | Description |
|--------|:---------:|-------------|
| `service_account_id` | No | Runtime SA ID (passthrough from input) |
| `topic_names` | No | List of created topic names |
---

## Module: `networking`

**Path:** `terraform/modules/networking/`
**Purpose:** Azure VNet infrastructure + PrivateLink endpoint to Confluent.

### Resources Created

| # | Resource | Type | Purpose |
|---|----------|------|---------|
| 1 | `azurerm_virtual_network.this` | VNet | Main network |
| 2 | `azurerm_subnet.private_endpoints` | Subnet | Hosts Private Endpoint NICs |
| 3 | `azurerm_subnet.aks` | Subnet | Hosts AKS node pool |
| 4 | `azurerm_network_security_group.pe` | NSG | PE subnet security rules |
| 5 | `azurerm_network_security_group.aks` | NSG | AKS subnet security rules |
| 6 | `azurerm_subnet_network_security_group_association.pe` | Association | PE subnet ↔ NSG |
| 7 | `azurerm_subnet_network_security_group_association.aks` | Association | AKS subnet ↔ NSG |
| 8 | `azurerm_private_endpoint.confluent` | Private Endpoint | PrivateLink connection to Confluent |
| 9 | `azurerm_private_dns_zone.confluent` | DNS Zone | `privatelink.confluent.cloud` |
| 10 | `azurerm_private_dns_zone_virtual_network_link.confluent` | VNet Link | DNS zone ↔ VNet |
| 11 | `azurerm_private_dns_a_record.confluent_bootstrap` | A Record | Bootstrap FQDN → PE IP |

### Key Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `vnet_name` | string | VNet display name (from CAF) |
| `vnet_address_space` | list(string) | VNet CIDR (default: `["10.0.0.0/22"]`) |
| `pe_subnet_prefix` | string | PE subnet CIDR |
| `aks_subnet_prefix` | string | AKS subnet CIDR |
| `confluent_private_link_service_aliases` | map(string) | Zone → PLS alias from Confluent module |
| `confluent_pe_zone` | string | Which zone's alias to use (default: `"1"`) |
| `confluent_dns_record_name` | string | DNS A record name for bootstrap |

### Key Outputs

| Output | Description |
|--------|-------------|
| `vnet_id` | VNet resource ID |
| `pe_subnet_id` | PE subnet resource ID |
| `aks_subnet_id` | AKS subnet resource ID (consumed by AKS module) |
| `private_endpoint_ip` | Private IP of the PE NIC |

---

## Module: `aks`

**Path:** `terraform/modules/aks/`
**Purpose:** Private AKS cluster with workload identity and dual node pools.

### Resources Created

| # | Resource | Type | Purpose |
|---|----------|------|---------|
| 1 | `azurerm_kubernetes_cluster.this` | AKS Cluster | Main cluster + system node pool |
| 2 | `azurerm_kubernetes_cluster_node_pool.user` | Node Pool | Application workload nodes |

### Architecture

```
AKS Cluster
├── System Node Pool (1 node, CriticalAddonsOnly taint)
│   └── CoreDNS, kube-proxy, metrics-server
└── User Node Pool (N nodes, label: workload=application)
    └── Application pods (Kafka producers/consumers)
```

### Key Inputs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | Cluster name (1-63 chars, validated) |
| `kubernetes_version` | string | `"1.35"` | K8s version (major.minor) |
| `node_count` | number | `2` | User node pool size (module: 1-1000; POC root: 1-5) |
| `vm_size` | string | `"Standard_D2s_v5"` | Node VM SKU |
| `subnet_id` | string | — | AKS subnet from networking module |
| `private_cluster_enabled` | bool | `false` | Private API server |
| `automatic_upgrade_channel` | string | `"patch"` | Auto-upgrade strategy |

### Key Outputs

| Output | Sensitive | Description |
|--------|:---------:|-------------|
| `cluster_name` | No | AKS cluster name |
| `kube_config_raw` | **Yes** | Full kubeconfig |
| `kubelet_identity_object_id` | No | MI object ID for Key Vault RBAC |
| `oidc_issuer_url` | No | OIDC issuer for Workload Identity |

---

## Module: `keyvault`

**Path:** `terraform/modules/keyvault/`
**Purpose:** Generic secret storage with RBAC access control.

### Resources Created

| # | Resource | Type | Purpose |
|---|----------|------|---------|
| 1 | `azurerm_key_vault.this` | Key Vault | Secret storage |
| 2 | `azurerm_role_assignment.deployer_secrets_officer` | RBAC | Terraform deployer → Secrets Officer |
| 3 | `azurerm_role_assignment.secrets_user` | RBAC | Reader principals → Secrets User (`for_each`) |
| 4 | `azurerm_key_vault_secret.this` | Secrets | Store secret map (`for_each`) |

### Design: Generic, Not Confluent-Specific

The Key Vault module accepts a generic `secrets` map and `reader_principal_ids` list — it has **no knowledge of Confluent**. The platform root module writes cluster metadata:

```hcl
# terraform/platform/main.tf
module "keyvault" {
  secrets = {
    "confluent-cluster-id"     = module.confluent.cluster_id
    "confluent-environment-id" = module.confluent.environment_id
    "confluent-rest-endpoint"  = module.confluent.cluster_rest_endpoint
    "confluent-bootstrap"      = module.confluent.cluster_bootstrap_endpoint
  }
  reader_principal_ids = { "aks-kubelet" = module.aks.kubelet_identity_object_id }
}
```

App team deployments read cluster metadata from KV. Confluent credentials come from GitHub Environment secrets (`TF_VAR_*`):
```hcl
# terraform/teams/orders/main.tf
data "azurerm_key_vault_secret" "cluster_id" {
  name         = "confluent-cluster-id"
  key_vault_id = var.key_vault_id
}

# Deployer + runtime credentials come from var.* (GitHub Environment)
# var.confluent_cloud_api_key, var.runtime_service_account_id, etc.
```

### Key Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `vault_name` | string | Globally unique vault name (from CAF) |
| `secrets` | map(string) | Secret name → value map (sensitive) |
| `reader_principal_ids` | list(string) | Principal IDs for Secrets User role |
| `allowed_ip_ranges` | list(string) | Management IPs for network ACL |

### Key Outputs

| Output | Sensitive | Description |
|--------|:---------:|-------------|
| `vault_uri` | No | Vault URI |
| `vault_name` | No | Vault name |
| `secret_uris` | **Yes** | Map of secret name → versionless URI |

---

## Variable Validation Strategy

```mermaid
graph TD
    subgraph Module["Module Level (reusable, always enforced)"]
        MV1["Format checks: CIDR, IPv4, UUID, length"]
        MV2["Range checks: node_count 1-1000"]
        MV3["Pattern checks: cluster_name, dns_prefix"]
    end
    
    subgraph Root["Root Level (business rules, environment-specific)"]
        RV1["Stricter ranges: aks_node_count 1-5 (POC cost)"]
        RV2["Business patterns: environment_short 2-5 chars"]
        RV3["Required formats: subscription UUID, region name"]
    end
    
    Root -->|"Tighter constraints"| Module
    
    style Module fill:#E8F0FE,stroke:#4472C4
    style Root fill:#FFF2E8,stroke:#ED7D31
```

**Principle:** Format checks live in modules (single source of truth). Root only adds stricter business constraints. No duplicate validations.
