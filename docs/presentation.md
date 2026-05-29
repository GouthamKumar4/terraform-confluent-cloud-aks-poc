---
marp: true
theme: default
paginate: true
header: "POC: Private Confluent Kafka + AKS via Terraform"
footer: "Confidential — May 2026"
---

# Private Confluent Cloud Kafka + AKS
## Terraform POC

**Date**: May 2026
**Status**: Ready for Review

---

# Problem Statement

- Manual Kafka provisioning is error-prone and insecure
- Need private-only access to Kafka (no public internet)
- Need controlled, auditable access via service accounts and ACLs
- Need AKS provisioned in the same automated workflow
- Secrets must be stored securely (not in code or state files)

---

# POC Objectives

1. Provision Confluent Cloud environment + Dedicated Kafka cluster via Terraform
2. Establish private connectivity (VNet + PrivateLink)
3. Create topics: `orders`, `payments`
4. Create service account + API key + ACLs (produce/consume)
5. Provision AKS cluster with workload identity
6. Store all secrets in Azure Key Vault
7. Provide reproducible runbook and CI/CD pipelines

---

# Architecture

```
Azure Subscription
├── VNet (10.0.0.0/16)
│   ├── PE Subnet → Private Endpoint → Confluent Cloud (PrivateLink)
│   └── AKS Subnet → AKS Cluster (workload identity)
├── Key Vault (API key, secret, bootstrap endpoint)
└── Private DNS Zone (resolves Kafka FQDN → private IP)

Confluent Cloud
├── Environment: poc-dev
├── Kafka Cluster: Dedicated, 1 CKU, westeurope
├── Topics: orders (3p), payments (3p)
├── Service Account: poc-app-sa
├── API Key → stored in Key Vault
└── ACLs: WRITE+READ on topics, READ on consumer group
```

---

# Security Model

| Layer | Control |
|-------|---------|
| Network | PrivateLink — no public endpoint |
| Identity | Service account with cluster-scoped API key |
| Authorization | ACLs: topic-level produce/consume only |
| Secrets | Key Vault with RBAC, purge protection |
| AKS | Workload identity for Key Vault access |
| Infra | NSGs on all subnets |

---

# Terraform Modules

| Module | Resources |
|--------|-----------|
| `confluent` | Environment, Cluster, Topics, SA, API Key, ACLs, PL Access |
| `networking` | VNet, Subnets, NSGs, Private Endpoint, DNS Zone |
| `aks` | AKS Cluster, Node Pool, Workload Identity |
| `keyvault` | Key Vault, Secrets, RBAC Assignments |

**Root module** (`environments/poc/`) composes all modules with a single `terraform apply`.

---

# GitHub Actions CI/CD

| Workflow | Trigger | Action |
|----------|---------|--------|
| `terraform-validate` | PR + push | Format check + validate |
| `terraform-plan` | PR | Plan + comment on PR |
| `terraform-apply` | Manual dispatch | Apply with confirmation gate |

Secrets managed via GitHub Secrets (ARM credentials + Confluent API key).

---

# Demo Flow

1. `terraform init` → providers + backend configured
2. `terraform plan` → ~25 resources shown
3. `terraform apply` → all resources created
4. Verify: cluster, topics, PE, DNS, AKS, Key Vault
5. Produce/consume test from AKS pod
6. Negative test: unauthorized access denied
7. `terraform destroy` → clean teardown

---

# Verification Results

| Check | Expected | Status |
|-------|----------|--------|
| Cluster provisioned | Dedicated, private | ✅ |
| Topics exist | orders, payments | ✅ |
| Private endpoint connected | Approved | ✅ |
| DNS resolves privately | Private IP | ✅ |
| AKS cluster ready | 2 nodes | ✅ |
| Key Vault secrets present | 3 secrets | ✅ |
| Produce/consume works | Messages flow | ✅ |
| Unauthorized access denied | Error returned | ✅ |

---

# Scope

## In Scope
- Confluent environment + Dedicated Kafka cluster
- Private networking (VNet + PrivateLink + DNS)
- Topics, service account, API key, ACLs
- AKS cluster provisioning
- Key Vault secret storage
- CI/CD pipelines (GitHub Actions)
- Documentation and runbook

## Out of Scope
- Production HA, multi-region, DR
- Performance/load testing
- Long-running operations

---

# Risks & Constraints

| Risk | Mitigation |
|------|-----------|
| Dedicated tier cost (~$1.50/hr) | Teardown immediately after demo |
| PrivateLink manual approval | Document in runbook |
| IAM propagation delay | Wait 5 min after RBAC assignments |
| Confluent region availability | Pre-verify region support |

---

# Next Steps After POC Approval

1. **Activate CI/CD** — configure GitHub Secrets, enable plan/apply
2. **Production architecture** — HA, multi-zone, auto-scaling
3. **Disable AKS local accounts** — enforce Entra ID-only auth (`local_account_disabled = true`) once AAD groups are verified
4. **Node Auto Provisioning (NAP)** — auto-creates optimal node pools based on pod demands (Azure's Karpenter)
5. **Policy-as-code** — OPA/Sentinel for governance
5. **Observability** — Confluent metrics + Azure Monitor
6. **Secret rotation** — Key Vault + Confluent API key lifecycle
7. **OIDC authentication** — eliminate stored client secrets for CI/CD
6. **Cost optimization** — right-size CKUs based on throughput needs

---

# Thank You

**Repository**: `<github-org>/confluent-kafka-poc`
**Runbook**: `docs/runbook.md`
**Contact**: `<team-email>`

Export this deck:
```bash
marp docs/presentation.md --pptx  # PowerPoint
marp docs/presentation.md --pdf   # PDF
```
