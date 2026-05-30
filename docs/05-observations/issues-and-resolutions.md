# Issues & Resolutions

> Problems encountered during POC development and how they were resolved.

---

## Issue Log

| # | Category | Issue | Resolution | Severity |
|---|----------|-------|------------|:--------:|
| 1 | Confluent | Missing `confluent_network` resource | Added to module | 🔴 Blocker |
| 2 | Naming | Repeated `azurecaf_name` blocks | Refactored to `for_each` | 🟡 Improvement |
| 3 | Key Vault | Module was Confluent-specific | Made generic with `secrets` map | 🟡 Improvement |
| 4 | Security | Sensitive outputs not marked | Added `sensitive = true` to 5 outputs | 🟠 Medium |
| 5 | PrivateLink | PE stuck in "Pending" state | Manual approval in Confluent Console | 🟡 Expected |
| 6 | RBAC | Key Vault access denied during apply | Added deployer → Secrets Officer role | 🔴 Blocker |
| 7 | Provider | Features block relied on implicit defaults | Made all values explicit | 🟡 Improvement |

---

## Issue 1: Missing Confluent Network Resource

**Category:** Confluent Module
**Severity:** 🔴 Blocker — deployment fails without it

**Problem:**
The initial Confluent module created an environment and cluster but skipped the `confluent_network` resource. Confluent requires a network resource with `PRIVATELINK` connection type before a Dedicated cluster can be attached to it.

**Error:**
```
Error: creating Kafka Cluster: cluster requires a network with PRIVATELINK connection type
```

**Resolution:**
Added `confluent_network.this` resource with proper dependency chain:

```
environment → network → private_link_access → cluster → ...
```

**Lesson:** Confluent's resource dependency chain is strict. Always provision: environment → network → PL access → cluster.

---

## Issue 2: Repeated CAF Name Blocks

**Category:** Naming / Code Quality
**Severity:** 🟡 Improvement

**Problem:**
Each Azure resource had its own `azurecaf_name` resource block — 10+ separate blocks with similar configuration. Adding a new resource meant copying another block.

**Resolution:**
Refactored to a single `azurecaf_name.this` with `for_each` over a map in `locals.tf`. Now adding a resource is one line in the map.

---

## Issue 3: Key Vault Module Was Confluent-Specific

**Category:** Module Design
**Severity:** 🟡 Improvement

**Problem:**
The Key Vault module had hardcoded variables like `confluent_api_key_id`, `confluent_api_key_secret`, and `kafka_bootstrap_endpoint`. This made the module unusable for any other project.

**Resolution:**
Replaced with a generic `secrets = map(string)` input and `reader_principal_ids = list(string)`. The root module now composes secrets from Confluent module outputs:

```hcl
secrets = {
  "confluent-api-key-id"     = module.confluent.api_key_id
  "confluent-api-key-secret" = module.confluent.api_key_secret
  "kafka-bootstrap-endpoint" = module.confluent.cluster_bootstrap_endpoint
}
```

**Lesson:** Modules should be generic. Domain-specific composition belongs in the root module.

---

## Issue 4: Sensitive Outputs Not Marked

**Category:** Security
**Severity:** 🟠 Medium — secrets could leak in CI/CD logs

**Problem:**
Only `api_key_secret` and `kube_config_raw` were marked `sensitive = true`. Outputs like `cluster_bootstrap_endpoint`, `cluster_rest_endpoint`, and `secret_uris` were printed in plain text during `terraform apply` and in CI/CD logs.

**Resolution:**
Added `sensitive = true` to 5 outputs across modules:
- `cluster_bootstrap_endpoint` (confluent)
- `cluster_rest_endpoint` (confluent)
- `kube_config_raw` (aks — already done)
- `secret_uris` (keyvault)
- `keyvault_secret_uris` (root)

**Lesson:** Audit ALL outputs — anything that reveals endpoints, paths, or credentials should be marked sensitive.

---

## Issue 5: PrivateLink Pending State

**Category:** Networking
**Severity:** 🟡 Expected behavior, documented

**Problem:**
After `terraform apply`, the Private Endpoint showed `Pending` connection status. AKS pods could not reach Kafka.

**Resolution:**
This is expected. The connection was created with `is_manual_connection = true`. It requires approval:
1. Automatic: Confluent may auto-approve for Dedicated clusters after a few minutes
2. Manual: Go to Confluent Console → Networking → Private Link → Approve

**Lesson:** Document this in the runbook as a post-apply step. Include wait time expectations.

---

## Issue 6: Key Vault Access Denied During Apply

**Category:** Security / RBAC
**Severity:** 🔴 Blocker — Terraform can't write secrets

**Problem:**
After creating the Key Vault with RBAC authorization, Terraform immediately tries to write secrets. But the deployer identity doesn't yet have the `Key Vault Secrets Officer` role on the new vault.

**Error:**
```
Error: creating Key Vault Secret: StatusCode=403 -- Caller is not authorized to perform action on resource
```

**Resolution:**
Added `azurerm_role_assignment.deployer_secrets_officer` that assigns the deployer identity (from `data.azurerm_client_config.current`) the `Key Vault Secrets Officer` role. Secret resources `depends_on` this role assignment.

**Lesson:** RBAC propagation takes up to 5 minutes. The `depends_on` ensures Terraform waits, but there may still be a delay. Retry on 403 errors.

---

## Issue 7: Provider Features Block — Implicit Defaults

**Category:** Provider Configuration
**Severity:** 🟡 Improvement — prevents future surprises

**Problem:**
The `azurerm` provider `features {}` block was empty, relying on default values. If a future provider version changes defaults (e.g., `purge_soft_delete_on_destroy` flips to `true`), the behavior changes silently.

**Resolution:**
Explicitly set all feature values:
```hcl
features {
  key_vault {
    purge_soft_delete_on_destroy    = false
    recover_soft_deleted_key_vaults = true
  }
  resource_group {
    prevent_deletion_if_contains_resources = true
  }
}
```

**Lesson:** Always pin provider feature flags. "Explicit is better than implicit."
