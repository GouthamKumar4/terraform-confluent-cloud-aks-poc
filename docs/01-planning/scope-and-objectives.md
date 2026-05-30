# Scope & Objectives

## POC Brief

> Provision a Private Confluent Cloud Kafka Cluster and Topics using Terraform, with an AKS cluster for workload execution and Key Vault for secret management.

**Requested By:** _(fill in)_
**Deadline:** 2 days for documentation/presentation review
**Date:** May 2026

---

## Success Criteria

| # | Criterion | How We Prove It |
|---|-----------|-----------------|
| 1 | Confluent Kafka cluster is **Dedicated** and **private-only** | No public endpoint; PrivateLink connected |
| 2 | Two topics (`orders`, `payments`) exist with correct ACLs | `terraform output` + Confluent Console |
| 3 | Service account has **least-privilege** access | ACLs: WRITE + READ on topics, READ on consumer group — nothing else |
| 4 | AKS cluster can **produce and consume** over private network | Kafka tools test from AKS pod |
| 5 | All secrets stored in **Key Vault** (not in code/state logs) | `az keyvault secret list` shows 3 secrets |
| 6 | Entire stack deployable with a single `terraform apply` | Runbook demonstrates end-to-end |
| 7 | CI/CD pipelines defined (validate, plan, apply) | GitHub Actions workflows exist |
| 8 | Documentation enables **anyone** to reproduce | Runbook + architecture + presentation |

---

## In Scope

| Area | Details |
|------|---------|
| **Confluent Cloud** | Environment, Dedicated Kafka cluster (1 CKU), PrivateLink network, 2 topics, 1 service account, 1 API key, ACLs |
| **Azure Networking** | VNet, 2 subnets (PE + AKS), NSGs, Private Endpoint, Private DNS zone |
| **Azure Kubernetes Service** | Private AKS cluster, system + user node pools, workload identity, OIDC issuer |
| **Azure Key Vault** | Standard SKU, RBAC auth, purge protection, 3 secrets (API key ID, secret, bootstrap endpoint) |
| **CI/CD** | GitHub Actions: format check, plan on PR, manual apply |
| **Documentation** | Architecture, runbook, presentation, decision records |

## Out of Scope

| Area | Why |
|------|-----|
| Production HA / multi-zone / DR | POC validates connectivity pattern only |
| Performance & load testing | Requires production-grade cluster sizing |
| Multi-region failover | Beyond POC scope; requires cluster linking |
| Schema Registry | Not needed for basic produce/consume validation |
| Application deployment on AKS | POC uses ad-hoc test pods, not a deployed app |
| Monitoring & alerting | Confluent metrics + Azure Monitor deferred to production |
| Secret rotation automation | Key Vault + Confluent lifecycle deferred |
| Network policies (Calico rules) | Calico CNI plugin is enabled but custom rules are deferred |

---

## Constraints

| Constraint | Impact |
|------------|--------|
| Dedicated tier costs ~$1.50/hr | Must teardown immediately after demo |
| PrivateLink requires Dedicated tier | Cannot use Basic or Standard Kafka clusters |
| Private AKS cluster | No direct `kubectl` — must use `az aks command invoke` |
| Confluent region availability | Must pre-verify PrivateLink support in target region |
| IAM propagation delay | RBAC assignments take up to 5 minutes to propagate |

---

## Assumptions

1. Azure subscription has sufficient quota for AKS nodes (2x Standard_D2s_v5)
2. Azure subscription is enabled for PrivateLink (most are by default)
3. Confluent Cloud organization exists and supports Dedicated tier
4. The reviewer has Azure CLI and Terraform installed locally (or uses CI/CD)
5. GitHub repository is available for CI/CD pipeline configuration

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [Architecture](../architecture.md) | Component design and data flow |
| [Network Design](../02-design/network-design.md) | VNet topology and connectivity |
| [Security & Permissions](../02-design/security-and-permissions.md) | IAM, RBAC, identity model |
| [Runbook](../04-runsteps-and-verification/runbook.md) | Step-by-step execution |
| [Decisions](../02-design/decisions/) | Architecture Decision Records |
