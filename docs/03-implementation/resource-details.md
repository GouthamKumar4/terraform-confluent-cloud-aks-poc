# Resource Details

> Complete inventory of all resources provisioned by this POC — both Terraform-managed and bootstrap (manual).

---

## Subscription & Environment

| Property | Value |
|----------|-------|
| **Subscription** | `poc` |
| **Region** | `westeurope` |
| **Environment** | `poc` |
| **Naming Format** | `<caf-prefix>-<team>-<env>-<suffix>` |
| **Team Name** | `unpr` |
| **Unique Suffix** | `001` |
| **Naming Convention** | Azure CAF (`azurecaf` provider) + manual for Confluent/bootstrap |
| **Tags** | `environment=poc`, `team=unpr`, `region=westeurope`, `managed_by=terraform` |

---

## Bootstrap Resources (Manual — NOT managed by Terraform)

> Created once in [Runbook §Prerequisites](../04-runsteps-and-verification/runbook.md#prerequisites--bootstrap). These exist BEFORE `terraform apply`.

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `rg-tfstate-unpr-poc-001` | Terraform state backend (shared) |
| Storage Account | `sttfstateunprpoc001` | State file storage (LRS, TLS 1.2, no public blob) |
| Blob Container | `tfstate` | State file container |
| **Managed Identity** | **`id-terraform-unpr-poc-001`** | **Terraform deployer (recommended — no secrets)** |
| Service Principal (alt) | `sp-terraform-unpr-poc-001` | Alternative if MI not feasible |

> **Why Managed Identity?** No client secret is generated — ever. Combined with OIDC federation for GitHub Actions, this is a fully **zero-secret** approach for Azure authentication. Service Principal is documented as a fallback but generates a password on creation.

### Role Assignments (on Managed Identity)

| Role | Scope | Why | Condition |
|------|-------|-----|----------|
| Contributor | Subscription | Create/manage all Azure resources | None |
| Role Based Access Control Administrator | Subscription | Assign KV Secrets Officer + Secrets User roles | ABAC: restricted to Key Vault roles only |

> **Least privilege:** No `Key Vault Administrator` or `User Access Administrator` needed. The ABAC condition prevents assigning any role except Key Vault Secrets Officer (`b86a8fe4`) and Key Vault Secrets User (`4633458b`).

---

## Terraform-Managed Resources (created by `terraform apply`)

### Resource Group & Shared

| # | Resource Type | Name (CAF) | SKU / Config | Module |
|---|--------------|------------|--------------|--------|
| 1 | `azurerm_resource_group` | `rg-unpr-poc-001` | — | root |
| 2 | `azurerm_log_analytics_workspace` | `log-unpr-poc-001` | PerGB2018, 30-day retention | root |

### Networking (11 resources)

| # | Resource Type | Name (CAF) | Config | Module |
|---|--------------|------------|--------|--------|
| 3 | `azurerm_virtual_network` | `vnet-unpr-poc-001` | `10.0.0.0/22` | networking |
| 4 | `azurerm_subnet` (PE) | `snet-unpr-poc-pe-001` | `10.0.0.0/26` | networking |
| 5 | `azurerm_subnet` (AKS) | `snet-unpr-poc-aks-001` | `10.0.1.0/24` (251 IPs) | networking |
| 6 | `azurerm_network_security_group` (PE) | `nsg-unpr-poc-pe-001` | Default rules | networking |
| 7 | `azurerm_network_security_group` (AKS) | `nsg-unpr-poc-aks-001` | Default rules | networking |
| 8 | `azurerm_subnet_network_security_group_association` | PE ↔ NSG | — | networking |
| 9 | `azurerm_subnet_network_security_group_association` | AKS ↔ NSG | — | networking |
| 10 | `azurerm_private_endpoint` | `pep-unpr-poc-001` | Manual connection | networking |
| 11 | `azurerm_private_dns_zone` | `privatelink.confluent.cloud` | — | networking |
| 12 | `azurerm_private_dns_zone_virtual_network_link` | VNet ↔ DNS zone | — | networking |
| 13 | `azurerm_private_dns_a_record` | Bootstrap endpoint → PE IP | — | networking |

### AKS (2 resources)

| # | Resource Type | Name (CAF) | Config | Module |
|---|--------------|------------|--------|--------|
| 14 | `azurerm_kubernetes_cluster` | `aks-unpr-poc-001` | See details below | aks |
| 15 | `azurerm_kubernetes_cluster_node_pool` | `user` | Application workloads | aks |

**AKS Cluster Configuration:**

| Property | Value |
|----------|-------|
| Kubernetes Version | `1.29` |
| Network Plugin | Azure CNI |
| Network Policy | Calico |
| Private Cluster | `true` (API server on private IP only) |
| SKU Tier | Free (POC) |
| OIDC Issuer | Enabled (for Workload Identity) |
| Workload Identity | Enabled |
| Azure RBAC | Enabled (Entra ID integration) |
| Auto-upgrade | Patch (security z-version) |
| Node OS Upgrade | SecurityPatch |
| Image Cleaner | Enabled (48h interval) |
| Monitoring | Container Insights → Log Analytics |

**Node Pools:**

| Pool | VM Size | Count | OS Disk | Purpose |
|------|---------|:-----:|---------|---------|
| `system` | Standard_D2s_v5 | 1 | Managed | CriticalAddonsOnly (control plane agents) |
| `user` | Standard_D2s_v5 | 2 | Managed | Application workloads |

**Service CIDR:** `10.1.0.0/16` | **DNS Service IP:** `10.1.0.10`

### Key Vault (6 resources)

| # | Resource Type | Name (CAF) | Config | Module |
|---|--------------|------------|--------|--------|
| 16 | `azurerm_key_vault` | `kv-unpr-poc-001` | Standard, RBAC, purge protection | keyvault |
| 17 | `azurerm_role_assignment` | Deployer → Secrets Officer | Write secrets during apply | keyvault |
| 18 | `azurerm_role_assignment` | AKS kubelet MI → Secrets User | Runtime secret reads | keyvault |
| 19 | `azurerm_key_vault_secret` | `confluent-api-key-id` | Confluent API key ID | keyvault |
| 20 | `azurerm_key_vault_secret` | `confluent-api-key-secret` | Confluent API key secret | keyvault |
| 21 | `azurerm_key_vault_secret` | `kafka-bootstrap-endpoint` | Kafka bootstrap URL | keyvault |

**Key Vault Configuration:**

| Property | Value |
|----------|-------|
| SKU | Standard |
| Authorization | Azure RBAC (not access policies) |
| Purge Protection | Enabled (7-day retention) |
| Network ACL | Deny by default, bypass AzureServices |
| Soft Delete | Enabled (7 days) |

### Confluent Cloud (12 resources)

| # | Resource Type | Name | Config | Module |
|---|--------------|------|--------|--------|
| 22 | `confluent_environment` | `poc` | Stream Governance: Essentials | confluent |
| 23 | `confluent_network` | `net-unpr-poc-001` | Azure, PrivateLink, westeurope | confluent |
| 24 | `confluent_private_link_access` | `kafka-unpr-poc-001-pl-access` | Grants subscription access | confluent |
| 25 | `confluent_kafka_cluster` | `kafka-unpr-poc-001` | Dedicated, 1 CKU, single-zone | confluent |
| 26 | `confluent_service_account` | `sa-app-unpr-poc-001` | Application identity | confluent |
| 27 | `confluent_api_key` | `sa-app-unpr-poc-001-api-key` | Cluster-scoped, bound to SA | confluent |
| 28 | `confluent_kafka_topic` | `orders` | 3 partitions | confluent |
| 29 | `confluent_kafka_topic` | `payments` | 3 partitions | confluent |
| 30 | `confluent_kafka_acl` | Producer → `orders` | WRITE, LITERAL | confluent |
| 31 | `confluent_kafka_acl` | Producer → `payments` | WRITE, LITERAL | confluent |
| 32 | `confluent_kafka_acl` | Consumer → `orders` | READ, LITERAL | confluent |
| 33 | `confluent_kafka_acl` | Consumer → `payments` | READ, LITERAL | confluent |
| 34 | `confluent_kafka_acl` | Consumer Group → `poc-*` | READ, PREFIXED | confluent |

---

## Resource Count Summary

| Module | Azure Resources | Confluent Resources | Total |
|--------|:-:|:-:|:-:|
| Root (RG + LAW) | 2 | — | 2 |
| Networking | 11 | — | 11 |
| AKS | 2 | — | 2 |
| Key Vault | 6 | — | 6 |
| Confluent | — | 13 | 13 |
| **Total** | **21** | **13** | **34** |

---

## Outputs (from `terraform output`)

| Output | Description | Sensitive |
|--------|-------------|:---------:|
| `resource_group_name` | Resource group name | No |
| `confluent_environment_id` | Confluent environment ID (e.g., `env-xxxxx`) | No |
| `confluent_cluster_id` | Kafka cluster ID (e.g., `lkc-xxxxx`) | No |
| `confluent_topic_names` | List of topic names | No |
| `vnet_id` | VNet resource ID | No |
| `aks_cluster_name` | AKS cluster name | No |
| `aks_oidc_issuer_url` | OIDC issuer URL for Workload Identity | No |
| `keyvault_uri` | Key Vault URI | No |
| `keyvault_secret_uris` | Map of secret name → versionless URI | **Yes** |

---

## Cost Estimate (POC)

| Resource | Cost | Notes |
|----------|------|-------|
| Confluent Dedicated (1 CKU) | ~$1.50/hr (~$36/day) | **Dominant cost** — teardown after demo |
| AKS (3x Standard_D2s_v5) | ~$0.30/hr | Free tier control plane |
| Key Vault | ~$0.03/10K operations | Negligible |
| Storage (TF state) | < $0.01/month | Negligible |
| Log Analytics | Pay-per-GB ingested | Minimal for POC |
| **Total (running)** | **~$1.80/hr (~$43/day)** | **Destroy immediately after verification** |

---

## Related Documents

- [Terraform Modules](terraform-modules.md) — Module design, dependency graph, variable strategy
- [Naming Conventions](../01-planning/naming-conventions.md) — CAF naming rules
- [Architecture](../architecture.md) — Component design + data flow
- [Runbook](../04-runsteps-and-verification/runbook.md) — Bootstrap + deploy + verify
