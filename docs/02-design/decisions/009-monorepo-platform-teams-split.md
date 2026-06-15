# ADR-009: Monorepo with Platform/Teams Folder Split

**Status:** Proposed
**Date:** June 2026
**Reviewer:** _(pending)_

## Context

A Confluent Cloud dedicated cluster with PrivateLink exposes two distinct APIs:

1. **Management API** (`api.confluent.cloud`) — public, creates environments, clusters, service accounts, RBAC bindings
2. **Data Plane API** (Kafka REST) — private, creates topics, ACLs; only reachable from inside the VNet via PrivateLink

This creates a **circular dependency**: topics require the Private Endpoint to exist (network path to data plane), but the PE is provisioned by the platform deployment that also creates the cluster. A single `terraform apply` cannot create both because the data plane is unreachable until the PE is fully provisioned and DNS is resolvable.

```
┌──────────────────────────────────────────────────────────────┐
│                    Circular Dependency                        │
│                                                              │
│  Topics (data plane) ──needs──▶ Private Endpoint             │
│         ▲                              │                     │
│         │                              │                     │
│         └────── created by ◀───────────┘                     │
│                 same deployment                               │
│                                                              │
│  PE needs confluent_network outputs → cluster must exist     │
│  Topics need PE to be active → PE must exist + DNS resolve   │
│  Single apply: cluster created → PE created → but topics     │
│  attempted simultaneously → data plane unreachable → FAIL    │
└──────────────────────────────────────────────────────────────┘
```

Additionally, in an enterprise context:
- The **platform/SRE team** owns the cluster, networking, AKS, and Key Vault
- **Application teams** (orders, payments, etc.) each own their topics, service accounts, and ACLs
- These teams have different release cadences, permissions, and approval chains
- Each team should only be able to affect their own resources (blast radius isolation)

We need a repo structure that breaks the circular dependency while enabling team autonomy.

## Options Considered

### Option A: Single deployment with `-target` (two-phase apply)

```
terraform/environments/poc/
  main.tf  ← everything in one state
```

**How:** Run `terraform apply -target=module.confluent -target=module.networking` first, then full `terraform apply`.

| Pros | Cons |
|------|------|
| No structural changes needed | `-target` is fragile, not recommended for CI/CD |
| Single state file, simple to reason about | Entire state is a blast radius — one bad apply destroys everything |
| Simple to understand initially | No team boundary — everyone touches the same code |
| | Cannot delegate topic ownership to app teams |
| | Not representative of enterprise patterns |
| | HashiCorp explicitly warns against `-target` in automation |

### Option B: Separate repos per team

```
GitHub: infra-platform/       ← Platform team repo
GitHub: kafka-topics-orders/  ← Orders team repo
GitHub: kafka-topics-payments/← Payments team repo
```

| Pros | Cons |
|------|------|
| Full team autonomy and isolation | Overhead for a POC (multiple repos, CI configs) |
| Independent release cycles | Module sharing requires Terraform registry or git submodules |
| Clear ownership via repo permissions | Harder to review end-to-end architecture in one place |
| Familiar to large enterprises | Onboarding new team = creating entire new repo + CI + permissions |

### Option C: Monorepo — single app folder with `for_each` + auto.tfvars

```
terraform/
  platform/           ← Platform team root module
  teams/              ← Single folder for ALL teams
    main.tf              module "team" { for_each = var.teams ... }
    teams.auto.tfvars    all teams defined in one map variable
    backend.tf           one shared state: "app.tfstate"
```

```hcl
# teams.auto.tfvars
teams = {
  orders   = { topics = [...], consumer_group_prefix = "orders-" }
  payments = { topics = [...], consumer_group_prefix = "payments-" }
}
```

| Pros | Cons |
|------|------|
| Fewest files — one folder, one tfvars | All teams share a single state file — blast radius is all topics |
| Add new team = add a block to tfvars (no code change) | One team's failed apply blocks all teams |
| Single CI workflow for all teams | No per-team state isolation |
| Simple `for_each` pattern | Cannot grant per-team permissions on state |
| | Splitting to separate repos later requires refactoring (not just moving a folder) |
| | One team merging a bad variable value breaks everyone's plan |
| | Not representative of enterprise team boundaries |

### Option D: Monorepo with platform + separate team folders (chosen)

```
terraform/
  platform/           ← Platform team root module
  teams/orders/       ← Orders team root module (own state)
  teams/payments/     ← Payments team root module (own state)
  modules/            ← Shared modules
```

| Pros | Cons |
|------|------|
| Single repo — full picture in one place | Need CODEOWNERS for path-based permissions |
| Shared modules via relative path (no registry needed) | Teams share a repo (less isolation than multi-repo) |
| Path-based CI triggers (only affected team's pipeline runs) | More files/folders than Option C |
| Each team has own state file (blast radius isolated) | |
| Easy to onboard new team (copy folder + tfvars) | |
| Easy to split into separate repos later (git filter-branch → new repo) | |
| Demonstrates enterprise pattern without enterprise overhead | |
| Per-team CI/CD — one team's failure doesn't block others | |

## Decision

Use **Option D — Monorepo with platform + separate team folders**.

### Why Option D over Option C (single folder + `for_each`)

| Concern | Option C (shared state) | Option D (per-team state) |
|---------|------------------------|--------------------------|
| Team A breaks their tfvars | All teams' `terraform plan` fails | Only Team A's pipeline fails |
| Rollback needed | Must rollback entire app state | Rollback only affected team's state |
| State file locking | All teams contend on one lock | Each team has independent lock |
| Permissions | Cannot restrict who modifies which team's topics | CODEOWNERS per folder path |
| Audit | "Who changed what" harder in shared state | Clear — each state tied to one team |
| Split to multi-repo | Requires refactoring `for_each` logic | Move folder → it already works as standalone root module |

**Key rationale:** For a POC this seems like over-engineering, but the goal is to demonstrate an enterprise-ready pattern. Per-team state isolation is a non-negotiable requirement in production because:
1. A payments team deploying a topic change should never risk destroying the orders team's topics
2. Teams deploy at different times — lock contention on a shared state causes CI/CD queuing
3. When we eventually split to separate repos, each folder is already a self-contained root module — zero refactoring needed

### Repository Structure

```
terraform/
  platform/                          ← GitHub-hosted runner (ubuntu-latest)
    backend.tf                          state key: "platform.tfstate"
    locals.tf
    main.tf                             env, network, cluster, VNet, PE, AKS, KV
    outputs.tf
    providers.tf
    variables.tf
    versions.tf
    platform.tfvars

  teams/
    orders/                          ← Self-hosted runner (AKS pod in VNet)
      backend.tf                        state key: "app-orders.tfstate"
      main.tf                           topics, SA, API key, ACLs
      providers.tf
      variables.tf
      versions.tf
      orders.tfvars

    payments/                        ← Self-hosted runner (AKS pod in VNet)
      backend.tf                        state key: "app-payments.tfstate"
      main.tf
      providers.tf
      variables.tf
      versions.tf
      payments.tfvars

  modules/
    confluent/                       ← Platform module (management API only)
    confluent-app/                   ← App module (data plane — topics, SA, ACLs)
    networking/
    aks/
    keyvault/

.github/workflows/
  platform-validate.yml              ← paths: terraform/platform/**
  platform-plan.yml
  platform-apply.yml
  app-orders-plan.yml                ← paths: terraform/teams/orders/**
  app-orders-apply.yml
  app-payments-plan.yml              ← paths: terraform/teams/payments/**
  app-payments-apply.yml
```

### Breaking the Circular Dependency

Two independent Terraform deployments with separate state files:

```
Deployment 1: Platform (public runner)
  ├── confluent_environment
  ├── confluent_network
  ├── confluent_private_link_access
  ├── confluent_kafka_cluster
  ├── azurerm_virtual_network + subnets
  ├── azurerm_private_endpoint + DNS zone    ← PE NOW EXISTS & RESOLVES
  ├── azurerm_kubernetes_cluster
  └── azurerm_key_vault
      └── writes: cluster_id, env_id, rest_endpoint

Deployment 2: App team (self-hosted runner inside VNet)
  ├── reads cluster_id, env_id, rest_endpoint FROM Key Vault
  ├── confluent_service_account
  ├── confluent_api_key
  ├── confluent_kafka_topic (orders / payments)
  ├── confluent_kafka_acl (WRITE per topic)
  ├── confluent_kafka_acl (READ per topic)
  └── confluent_kafka_acl (consumer group)
      └── writes: api-key-id, api-key-secret TO Key Vault
```

By the time Deployment 2 runs, the PE is fully provisioned and DNS is resolvable — the data plane is reachable. Circular dependency eliminated.

### Inter-deployment Communication via Key Vault

Platform writes shared configuration to **Azure Key Vault** (not `terraform_remote_state`):

| Secret Name | Value | Written By | Read By |
|---|---|---|---|
| `confluent-cluster-id` | `lkc-xxxxx` | Platform TF | App teams |
| `confluent-environment-id` | `env-xxxxx` | Platform TF | App teams |
| `confluent-rest-endpoint` | `https://pkc-xxxxx...` | Platform TF | App teams |
| `confluent-bootstrap` | `pkc-xxxxx...:9092` | Platform TF | App teams + AKS pods |
| `<team>-deployer-cloud-api-key` | Cloud API key | Cloud admin (manual) | App team TF |
| `<team>-runtime-sa-id` | SA ID | Cloud admin (manual) | App team TF |
| `<team>-runtime-cluster-api-key` | Cluster API key | Cloud admin (manual) | App team TF + AKS pods |

**Why Key Vault over `terraform_remote_state`:**

| Factor | Key Vault | Remote State |
|---|---|---|
| Exposure | Only chosen values | Entire state (secrets in plaintext) |
| Access control | Azure RBAC per secret | Storage account IAM (all-or-nothing) |
| Cross-repo ready | Works unchanged after repo split | Needs backend reconfiguration |
| Coupling | Loose (secret names as contract) | Tight (must know backend details) |
| HashiCorp guidance | Recommended for cross-team | Discouraged for cross-team |

### Runner Model

| Deployment | Runner Type | Reason |
|---|---|---|
| Platform | `ubuntu-latest` (GitHub-hosted) | Only management API — reachable from public internet |
| App teams | Self-hosted on AKS pod | Data plane — only reachable via PrivateLink from inside VNet |

### Onboarding a New Team

```bash
# 1. Copy template
cp -r terraform/teams/orders terraform/teams/shipping

# 2. Edit tfvars
# terraform/teams/shipping/shipping.tfvars:
#   team_name = "shipping"
#   topics    = [{ name = "shipments", partitions = 6 }]

# 3. Add workflow
# .github/workflows/app-shipping-plan.yml (copy + change paths trigger)

# 4. PR → review → merge → done
```

### Future: Splitting to Separate Repos

```
Today (monorepo):                         Future (multi-repo):

terraform/teams/orders/              →    New repo: kafka-topics-orders/
terraform/teams/payments/            →    New repo: kafka-topics-payments/
terraform/modules/confluent-app/     →    Published to Terraform private registry

Only change in team code:
  source = "../../modules/confluent-app"
  becomes:
  source = "app.terraform.io/myorg/confluent-app/confluent"
```

## Consequences

### Positive
- Breaks the circular dependency cleanly — two sequential deployments
- Each team has isolated state (cannot destroy other team's resources)
- Demonstrates enterprise multi-team pattern without multi-repo overhead
- Onboard new team = copy folder + add workflow + PR
- Future split to multi-repo requires only module source change
- Key Vault as integration point works regardless of repo structure
- Path-based CI triggers — team changes only trigger their pipeline

### Negative
- More files/folders than a single-deployment approach
- Self-hosted runner (AKS pod) must be running before app teams can deploy
- Two separate `terraform apply` steps (not a single command)
- Key Vault secret names become a contract between teams

### Mitigations
- Self-hosted runner is deployed by platform team as part of AKS setup (automated)
- Secret name contract documented in shared `modules/confluent-app/README.md`
- Template folder pattern makes onboarding mechanical (no guesswork)
- Platform must be applied first — enforced by CI dependency (app workflows check KV secrets exist)
