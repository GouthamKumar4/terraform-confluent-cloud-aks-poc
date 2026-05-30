# Naming Conventions

> All resource names use the **team name** (`team_name`) as the identifier. One variable drives every name.

---

## Format

```
<caf-prefix>-<team>-<env>-<suffix>
```

### How to Read a Name

Take `rg-unpr-poc-001`:

```
  rg     -   unpr    -   poc   -   001
  ──┬──      ──┬──       ─┬─       ─┬─
    │          │          │         └─ Instance number
    │          │          └─────────── Environment
    │          └────────────────────── Team name
    └───────────────────────────────── Resource type (Azure CAF)
```

### How It Works in Terraform

One variable — everything is derived:

```hcl
# poc.tfvars
team_name = "unpr"   # ← team name

# locals.tf
team_env = "${var.team_name}-${var.environment_short}"  # → "unpr-poc"

# All names generated:
#   rg-unpr-poc-001, vnet-unpr-poc-001, aks-unpr-poc-001
#   kafka-unpr-poc-001 (cluster), sa-app-unpr-poc-001
```

| Segment | Description | Example Values |
|---------|-------------|----------------|
| `caf-prefix` | Azure CAF abbreviation (auto-generated) | `rg`, `vnet`, `aks`, `kv`, `pep`, `nsg` |
| `team` | Team name | `unpr`, `payments`, `core` |
| `env` | Environment | `poc`, `dev`, `stg`, `prd` |
| `suffix` | Instance number | `001`, `002` |

### All Resources

| Category | Examples |
|----------|---------|
| **Azure infra** | `rg-unpr-poc-001`, `aks-unpr-poc-001`, `kv-unpr-poc-001`, `vnet-unpr-poc-001` |
| **Confluent** | `kafka-unpr-poc-001` (cluster), `sa-app-unpr-poc-001`, `net-unpr-poc-001` |
| **Bootstrap** | `rg-tfstate-unpr-poc-001`, `sttfstateunprpoc001`, `sc-tfstate-unpr-poc-001`, `id-terraform-unpr-poc-001` |

---

## Strategy

| Platform | Approach | Tool |
|----------|----------|------|
| **Azure resources** | [Cloud Adoption Framework (CAF)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) | `azurecaf` Terraform provider |
| **Confluent Cloud resources** | Manual naming (same `<type>-<team>-<env>-<suffix>` pattern) | `locals.tf` |
| **Bootstrap resources** | Manual (same pattern, created before `terraform apply`) | Runbook Step A-B |
| **Terraform resource labels** | `"this"` for single-instance resources | Industry standard |

---

## Azure Resources — CAF Naming

```hcl
resource "azurecaf_name" "this" {
  for_each      = local.azure_resource_names
  name          = local.team_env    # → "unpr-poc"
  resource_type = each.value.resource_type
  suffixes      = [var.unique_suffix]   # → "001"
  clean_input   = true
}
```

| Resource | Generated Name |
|----------|---------------|
| Resource Group | `rg-unpr-poc-001` |
| Virtual Network | `vnet-unpr-poc-001` |
| Subnet (PE) | `snet-unpr-poc-pe-001` |
| Subnet (AKS) | `snet-unpr-poc-aks-001` |
| NSG (PE) | `nsg-unpr-poc-pe-001` |
| NSG (AKS) | `nsg-unpr-poc-aks-001` |
| Private Endpoint | `pep-unpr-poc-001` |
| AKS Cluster | `aks-unpr-poc-001` |
| Key Vault | `kv-unpr-poc-001` |
| Log Analytics | `log-unpr-poc-001` |

---

## Confluent Cloud Resources — Manual Naming

Same team name pattern, defined in `locals.tf`:

| Resource | Generated Name |
|----------|---------------|
| Environment | `poc` |
| Network | `net-unpr-poc-001` |
| Cluster | `kafka-unpr-poc-001` |
| Service Account | `sa-app-unpr-poc-001` |
| Topics | `orders`, `payments` (user-defined) |
| DNS Zone | `privatelink.confluent.cloud` (fixed) |

---

## Bootstrap Resources — Manual Naming

Created once BEFORE `terraform apply`. These use an extra `purpose` segment to avoid collision with workload resources (e.g., two RGs for the same team):

```
Standard:   <prefix>-<team>-<env>-<suffix>                → rg-unpr-poc-001
Bootstrap:  <prefix>-<purpose>-<team>-<env>-<suffix>      → rg-tfstate-unpr-poc-001
                      ───┬───
                         └─ "tfstate" or "terraform" — distinguishes from workload RG
```

| Resource | Generated Name |
|----------|---------------|
| Resource Group | `rg-tfstate-unpr-poc-001` |
| Storage Account | `sttfstateunprpoc001` |
| Managed Identity | `id-terraform-unpr-poc-001` |
| Service Principal (alt) | `sp-terraform-unpr-poc-001` |

> **Why the extra segment?** Without `tfstate`, the state RG and workload RG would both be `rg-unpr-poc-001`. The purpose segment resolves this collision. Only bootstrap resources need it.
>
> **Storage accounts** cannot contain hyphens — use concatenation: `st` + `tfstate` + `unpr` + `poc` + `001`

---

## Terraform Resource Labels — `"this"` Pattern

Single-instance resources use `"this"` as the label:

```hcl
# ✅ Good — single instance
resource "azurerm_resource_group" "this" { ... }
resource "azurerm_key_vault" "this" { ... }

# ✅ Good — multiple instances of same type, use descriptive names
resource "azurerm_subnet" "aks" { ... }
resource "azurerm_subnet" "private_endpoints" { ... }

# ❌ Bad — redundant naming
resource "azurerm_resource_group" "resource_group" { ... }
```

**Why?** Industry standard from `terraform-aws-modules`, Azure Verified Modules, and Google Cloud Foundation Toolkit. Avoids `azurerm_resource_group.resource_group` redundancy.

---

## Tags — Applied to All Azure Resources

Every Azure resource receives these tags (via `local.common_tags`):

| Tag Key | Value | Source |
|---------|-------|--------|
| `environment` | `poc` | `var.environment_short` |
| `team` | `unpr` | `var.team_name` |
| `region` | `westeurope` | `var.location` |
| `managed_by` | `terraform` | Hardcoded |
| `project` | `confluent-kafka-poc` | `var.tags` (default) |

Custom tags can be added via `var.tags` in `poc.tfvars`.

---

## Key Vault Secret Names

| Secret Name | Content | Source |
|-------------|---------|--------|
| `confluent-api-key-id` | Confluent API key identifier | Confluent module output |
| `confluent-api-key-secret` | Confluent API key secret value | Confluent module output |
| `kafka-bootstrap-endpoint` | Private bootstrap server address | Confluent module output |

Convention: `<service>-<purpose>` with hyphens (Key Vault restriction: alphanumeric + hyphens only).

---

## GitHub Secrets Naming

| Secret Name | Convention | Description |
|-------------|-----------|-------------|
| `ARM_CLIENT_ID` | Azure standard | Managed Identity client ID |
| `ARM_TENANT_ID` | Azure standard | Azure AD tenant ID |
| `ARM_SUBSCRIPTION_ID` | Azure standard | Target subscription |
| `ARM_USE_OIDC` | Azure standard | Set to `true` (GitHub Variable, not Secret) |
| `CONFLUENT_CLOUD_API_KEY` | `CONFLUENT_*` prefix | Org-level API key |
| `CONFLUENT_CLOUD_API_SECRET` | `CONFLUENT_*` prefix | Org-level API secret |

> **No `ARM_CLIENT_SECRET` needed.** Managed Identity + OIDC = zero Azure secrets.
