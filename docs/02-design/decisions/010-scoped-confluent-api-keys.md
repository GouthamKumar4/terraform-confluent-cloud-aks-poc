# ADR-010: Scoped Confluent API Keys + Topic Prefix Isolation

**Status:** Proposed
**Date:** June 2026
**Reviewer:** _(pending)_

## Context

The platform and app team deployments both use the Confluent Terraform provider, which authenticates via a **Cloud API key**. Initially, both shared the same OrganizationAdmin-scoped key stored as a GitHub Secret.

**Risks with shared OrganizationAdmin key:**

| Risk | Impact | Likelihood |
|------|--------|:----------:|
| App team deletes the Kafka cluster | Full outage — all teams affected | Low (accidental) |
| App team deletes the environment | Full outage — cluster + network gone | Low |
| App team modifies another team's topics | Data loss or schema mismatch | Medium |
| Leaked key grants org-level access | Full Confluent org compromise | Low |

## Decision

Use **per-team Confluent service accounts** with prefix-scoped `ResourceOwner` roles, **manually created** by cloud admin:

| Identity | Role | Scope | Used By | Created By |
|----------|------|-------|---------|------------|
| `sa-terraform-unpr-poc-001` | `OrganizationAdmin` | Organization | Platform only | Manual (Runbook Step D) |
| `sa-deployer-orders-poc-001` | `ResourceOwner` | `Topic:orders*` + `Group:orders*` | Orders team TF (deployer) | Manual (Runbook Step D.2) |
| `sa-deployer-payments-poc-001` | `ResourceOwner` | `Topic:payments*` + `Group:payments*` | Payments team TF (deployer) | Manual (Runbook Step D.2) |
| `sa-app-orders-poc-001` | _(no roles — ACLs only)_ | Per-topic ACLs | Orders AKS pods (runtime) | Manual (Runbook Step D.2) |
| `sa-app-payments-poc-001` | _(no roles — ACLs only)_ | Per-topic ACLs | Payments AKS pods (runtime) | Manual (Runbook Step D.2) |

Cloud admin creates **both** the deployer SA and the runtime SA per team. The deployer SA gets `ResourceOwner` on the team's topic + consumer group prefix. The runtime SA gets a cluster-scoped API key (for produce/consume). All credentials are stored in GitHub Environment secrets (scoped per deployment target). App team Terraform only creates topics and ACLs — no SAs or API keys.

### Why ResourceOwner (not EnvironmentAdmin or DeveloperManage)?

By moving runtime SA + API key creation to the cloud admin, the deployer SA only needs topic and ACL operations. This allows `ResourceOwner` — the tightest role:

| Operation | `ResourceOwner` on prefix | `DeveloperManage` | `EnvironmentAdmin` |
|-----------|:-------------------------:|:------------------:|:-------------------:|
| Create topics (`<team>*`) | ✅ | ✅ | ✅ |
| Create ACLs on owned topics | ✅ | ✅ | ✅ |
| Create topics (`other-team*`) | ❌ (403) | ❌ (403) | ✅ |
| Create service accounts | ❌ | ❌ | ❌ (org-level only) |
| Create cluster API keys | ❌ | ❌ | ✅ |
| Delete cluster/environment | ❌ | ❌ | ❌ |

`ResourceOwner` gives **Confluent-level prefix enforcement** — the API itself returns 403 if orders-team tries to create `payments-*` topics. No reliance on Terraform validation alone.

### Topic Prefix Enforcement (Defence in Depth)

Topic prefix isolation is enforced at **three levels**:

1. **Confluent RBAC** — `ResourceOwner` scoped to `Topic:<team>*` — API returns 403 for wrong prefix
2. **Terraform validation** — `confluent-app` module validates `startswith(topic.name, var.team_name)`
3. **CODEOWNERS** — each team's folder requires approval from that team's lead

### API Key Flow

```
┌─────────────────────────────────────────────────────────┐
│ GitHub Secrets (Platform only)                          │
│   CONFLUENT_CLOUD_API_KEY    ──► OrganizationAdmin       │
│   CONFLUENT_CLOUD_API_SECRET ──► (creates env, cluster)  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Cloud Admin (manual, per team onboarding)                │
│                                                         │
│ Per team (e.g., orders):                                │
│   1. Creates deployer SA: sa-deployer-orders-poc-001    │
│   2. Assigns ResourceOwner on Topic:orders* + Group:orders*│
│   3. Generates Cloud API key for deployer SA            │
│   4. Creates runtime SA: sa-app-orders-poc-001          │
│   5. Generates cluster API key for runtime SA           │
│   6. Stores ALL in GitHub Environment (orders-poc):     │
│      - CONFLUENT_CLOUD_API_KEY/SECRET (deployer)        │
│      - CONFLUENT_RUNTIME_SA_ID                          │
│      - CONFLUENT_RUNTIME_API_KEY/SECRET                 │
└─────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────────┐
│ GitHub Environment (per-team secrets)                    │
│                                                         │
│ orders-poc:                                             │
│   CONFLUENT_CLOUD_API_KEY        ─► TF provider auth     │
│   CONFLUENT_CLOUD_API_SECRET                            │
│   CONFLUENT_RUNTIME_SA_ID        ─► TF module input      │
│   CONFLUENT_RUNTIME_API_KEY      ─► TF module + pods     │
│   CONFLUENT_RUNTIME_API_SECRET   ─► TF module + pods     │
│                                                         │
│ payments-poc: (same pattern)                            │
└─────────────────────────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
         Orders TF                 Payments TF
         (ResourceOwner:orders*)   (ResourceOwner:payments*)
              │                         │
         Creates topics:           Creates topics:
         orders* only              payments* only
         (Confluent 403 on         (Confluent 403 on
          payments* attempt)        orders* attempt)
              │                         │
         Creates ACLs for          Creates ACLs for
         runtime SA on             runtime SA on
         orders* topics            payments* topics
```

## Consequences

### Positive
- **Confluent-level prefix isolation** — `ResourceOwner` on `Topic:orders*` means API returns 403 for `payments*`. Not just Terraform validation
- **Blast radius minimized** — deployer cannot delete cluster, environment, network, or access other teams' prefixes
- **Per-team isolation** — each team has its own deployer SA, runtime SA, and GitHub Environment secrets
- **No org key on self-hosted runner** — app teams only see their own scoped key via GitHub Environment
- **Explicit approval gate** — no team gets access without admin manually creating both SAs
- **Auditable** — separate SA per team means separate audit trail in Confluent
- **App TF is simple** — only creates topics + ACLs, no SA/key lifecycle management

### Negative
- **More admin work per team** — admin must create 2 SAs + role bindings + Cloud API key + cluster API key + add 5 secrets to GitHub Environment. Fine for 5 teams, consider automation at 20+
- **Key rotation is manual** — Cloud and cluster API keys don't auto-expire; document rotation SOP
- **More GitHub Environment secrets** — 5 secrets per team (deployer key/secret, runtime SA ID, runtime key/secret)

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Shared OrganizationAdmin key** | Simple | App teams can delete cluster |
| **EnvironmentAdmin per team** | Deployer creates SA + API keys itself (fewer admin steps) | Broad — can manage any topic in env. No Confluent-level prefix enforcement |
| **CloudClusterAdmin per team** | Scoped to single cluster | Still no prefix enforcement at Confluent level |
| **Platform TF auto-creates deployer SA** | Zero manual work | Platform must know team list upfront; tightly coupled |
| **Dedicated onboarding module** | Separates concerns | Effectively same as a platform PR |
| **DeveloperManage per prefix** | Similar to ResourceOwner | Cannot delegate access or manage ACLs on owned resources |
| **Separate clusters per team** | Full isolation | Expensive ($1.50/hr per cluster) |
| **OPA/Sentinel in CI** | Policy enforcement before apply | Complex setup, doesn't prevent local runs |
