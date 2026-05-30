# ADR-005: Use Azure CAF Naming Convention

**Status:** Proposed
**Date:** May 2026
**Reviewer:** _(pending)_

## Context

Azure resources need consistent, meaningful names. Options:

| Approach | Example | Pros | Cons |
|----------|---------|------|------|
| **Freeform** | `my-rg`, `prod-vnet` | Simple | Inconsistent, no enforcement |
| **Manual convention** | `rg-project-env-001` | Consistent if followed | No tooling, easy to drift |
| **Azure CAF via `azurecaf` provider** | Auto-generated per [CAF spec](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations) | Enforced, consistent, length-aware | Extra provider dependency |

## Decision

Use the **`azurecaf` Terraform provider** with a single `for_each` resource block for all Azure resources. Use **manual naming** for Confluent Cloud resources (not supported by CAF).

## Consequences

### Positive
- **Enforced** — abbreviations, length limits, character restrictions all handled by the provider
- **DRY** — single `azurecaf_name.this` resource with `for_each`, not N separate blocks
- **Discoverable** — any Azure engineer recognizes CAF-compliant names
- **Scalable** — adding a new resource = adding one entry to the `for_each` map

### Negative
- **Provider dependency** — `azurecaf ~> 1.2` must be maintained
- **Doesn't cover Confluent** — manual naming convention needed for non-Azure resources
- **Name generation opacity** — generated names may not be immediately obvious without checking `locals.tf`

### Implementation

See [Naming Conventions](../../01-planning/naming-conventions.md) for the full reference table.
