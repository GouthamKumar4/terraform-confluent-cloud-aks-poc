# Private Confluent Cloud Kafka + AKS — Terraform POC

## What This Is

A proof-of-concept that provisions a **private** Confluent Cloud Kafka cluster (Dedicated tier, PrivateLink) with an AKS cluster — fully automated via Terraform. No public endpoints. Secrets stored in Azure Key Vault. Reproducible with a single `terraform apply`.

<!-- DIAGRAM PLACEHOLDER: Insert a simplified architecture overview image here -->
<!-- Save as: docs/assets/architecture-hero.png — a clean, high-level visual for the README -->
<!-- ![Architecture](docs/assets/architecture-hero.png) -->
![Architecture](docs/assets/architecture-hero.png)
```
Data Flow:  AKS Pod → Key Vault (get creds) → DNS (resolve FQDN) → Private EP → PrivateLink → Kafka
```

---

## How to Read This Repository

> Follow the numbered sections below. Each links to detailed documentation.

### Phase 1: Understand the Plan

| Step | Document | What You'll Learn |
|:----:|----------|-------------------|
| 1 | [Scope & Objectives](docs/01-planning/scope-and-objectives.md) | What's in scope, success criteria, constraints |

### Phase 2: Understand the Design

| Step | Document | What You'll Learn |
|:----:|----------|-------------------|
| 2 | [Architecture](docs/architecture.md) | Components, data flow, security overview |
| 3 | [Network Design](docs/02-design/network-design.md) | VNet topology, CIDR plan, DNS resolution, PrivateLink flow |
| 4 | [Security & Permissions](docs/02-design/security-and-permissions.md) | IAM roles, identity model, secret management |
| 5 | [Naming Conventions](docs/01-planning/naming-conventions.md) | Azure CAF + Confluent naming rules |
| 6 | [Design Decisions (ADRs)](docs/02-design/decisions/) | Why Dedicated tier, PrivateLink, Workload Identity, RBAC, CAF |
| 7 | [Terraform Modules](docs/03-implementation/terraform-modules.md) | Module reference, dependency graph, variable strategy |
| 8 | [Resource Details](docs/03-implementation/resource-details.md) | Full resource inventory, names, SKUs, costs |

### Phase 3: Execute & Verify

| Step | Document | What You'll Learn |
|:----:|----------|-------------------|
| 9 | [Runbook](docs/04-runsteps-and-verification/runbook.md) | Prerequisites (A-F) → Deploy (1-5) → Verify (V1-V8) |
| 10 | [CI/CD Runbook](docs/04-runsteps-and-verification/cicd.md) | GitHub Actions workflows (optional for POC) |

### Phase 4: Observe & Improve

| Step | Document | What You'll Learn |
|:----:|----------|-------------------|
| 11 | [Issues & Resolutions](docs/05-observations/issues-and-resolutions.md) | Problems encountered and how we solved them |
| 12 | [Future Improvements](docs/05-observations/future-improvements.md) | Out-of-scope items for production |

### Summary & Presentation

| Document | Audience |
|----------|----------|
| [Executive Summary](docs/executive-summary.md) | Management — 1-page overview |
| [Presentation](docs/presentation.md) | Reviewers — standalone deck (export to PPTX/PDF) |
---

## Repository Structure

```
├── README.md                              ← You are here (navigation hub)
├── context.md                             ← Original POC brief
├── CHANGELOG.md                           ← Implementation change log
├── .github/workflows/                     ← CI/CD pipelines
│   ├── terraform-validate.yml             ← PR + push: format + validate
│   ├── terraform-plan.yml                 ← PR: plan + comment
│   └── terraform-apply.yml                ← Manual dispatch: apply
├── terraform/
│   ├── environments/poc/                  ← Root module (single terraform apply)
│   │   ├── main.tf                        ← Module composition
│   │   ├── variables.tf                   ← Input variables (with validations)
│   │   ├── outputs.tf                     ← Stack outputs
│   │   ├── locals.tf                      ← CAF naming + tags
│   │   ├── poc.tfvars                     ← Non-sensitive config (committed)
│   │   ├── providers.tf                   ← Provider configuration
│   │   ├── versions.tf                    ← Required providers + versions
│   │   └── backend.tf                     ← Remote state backend
│   └── modules/
│       ├── confluent/                     ← Kafka cluster, topics, ACLs
│       ├── networking/                    ← VNet, PE, DNS
│       ├── aks/                           ← AKS cluster + node pools
│       └── keyvault/                      ← Secret storage
└── docs/
    ├── 01-planning/                       ← Scope, naming
    ├── 02-design/                         ← Network, security, ADRs
    │   └── decisions/                     ← Architecture Decision Records
    ├── 03-implementation/                 ← Terraform module reference
    ├── 04-runsteps-and-verification/      ← Runbook + CI/CD + evidence
    ├── 05-observations/                   ← Issues, improvements
    ├── architecture.md                    ← Component design + data flow
    ├── presentation.md                    ← Standalone presentation (Marp)
    ├── executive-summary.md               ← Management summary
    └── assets/                            ← Diagrams + screenshots
```

---

## Quick Start (for experienced users)

```bash
cd terraform/environments/poc

# Set sensitive vars
export TF_VAR_confluent_cloud_api_key="your-key"
export TF_VAR_confluent_cloud_api_secret="your-secret"
export TF_VAR_azure_subscription_id="your-subscription-id"

# Deploy
terraform init
terraform plan -var-file=poc.tfvars -out=tfplan
terraform apply tfplan
```

> **First time?** Start with [Prerequisites](docs/04-runsteps-and-verification/runbook.md#prerequisites--bootstrap) — there are one-time setup steps before this works.

---

## CI/CD Pipeline

```mermaid
graph LR
    PR["Pull Request"] -->|auto| V["Validate<br>(fmt + validate)"]
    PR -->|auto| P["Plan<br>(plan + PR comment)"]
    P -->|manual dispatch| A["Apply<br>(confirm gate)"]
    
    style V fill:#70AD47,color:#fff
    style P fill:#4472C4,color:#fff
    style A fill:#ED7D31,color:#fff
```

| Workflow | Trigger | Action |
|----------|---------|--------|
| [terraform-validate](.github/workflows/terraform-validate.yml) | PR + push to main | Format check + validate |
| [terraform-plan](.github/workflows/terraform-plan.yml) | PR | Plan + post as PR comment |
| [terraform-apply](.github/workflows/terraform-apply.yml) | Manual dispatch | Apply with `"apply"` confirmation gate |

---

## Cleanup

```bash
cd terraform/environments/poc
terraform destroy -var-file=poc.tfvars
```

> ⚠️ Dedicated Kafka costs ~$1.50/hr. Teardown immediately after verification.

---

## Security Highlights

| Control | Implementation |
|---------|---------------|
| No public Kafka endpoint | PrivateLink-only (Dedicated tier) |
| No public AKS API | `private_cluster_enabled = true` |
| Secrets in Key Vault | RBAC auth, purge protection, deny-by-default ACL |
| No secrets in code | `TF_VAR_*` env vars + GitHub Secrets |
| Least-privilege ACLs | Topic-level WRITE/READ only, prefixed consumer group |
| Sensitive outputs | 5 outputs marked `sensitive = true` |

> Full details: [Security & Permissions](docs/02-design/security-and-permissions.md)
