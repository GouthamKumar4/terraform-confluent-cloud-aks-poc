# ADR-004: Use Key Vault RBAC over Access Policies

**Status:** Proposed
**Date:** May 2026
**Reviewer:** _(pending)_

## Context

Azure Key Vault supports two authorization models:

| Model | How It Works | Management |
|-------|-------------|------------|
| **Access Policies** | Vault-level permissions per principal (legacy) | Key Vault → Access policies blade |
| **Azure RBAC** | Standard Azure role assignments on the vault resource | IAM blade, same as all Azure resources |

## Decision

Use **Azure RBAC** (`enable_rbac_authorization = true`) for Key Vault authorization.

## Consequences

### Positive
- **Consistent** — same RBAC model as every other Azure resource (no special Key Vault-specific policy model)
- **Granular** — roles like `Key Vault Secrets User` (read-only) vs `Key Vault Secrets Officer` (read/write) vs `Key Vault Administrator` (full control)
- **Auditable** — role assignments visible in Azure Activity Log and IAM blade
- **Scalable** — can use Azure AD groups, Conditional Access, PIM (Privileged Identity Management)
- **Terraform-friendly** — uses standard `azurerm_role_assignment` resources

### Negative
- **Propagation delay** — RBAC assignments take up to 5 minutes to propagate (Access Policies are instant)
- **Depends on Azure AD** — if AAD is unavailable, RBAC check fails (Access Policies are local to vault)

### Roles Used in This POC

| Role | Assigned To | Purpose |
|------|-------------|---------|
| `Key Vault Secrets Officer` | Terraform deployer identity | Write secrets during provisioning |
| `Key Vault Secrets User` | AKS kubelet identity | Read secrets at runtime |
| `Key Vault Administrator` | Service principal (subscription-level) | Create vault + assign RBAC |
