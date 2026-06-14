---
marp: true
theme: gaia
paginate: true
backgroundColor: #fff
backgroundImage: url('assets/backgroundimage.jpg')
backgroundSize: cover
color: #000
style: |
  section { font-size: 24px; padding: 40px 50px; color: #000; }
  h1 { color: #0078d4; font-size: 36px; margin-bottom: 16px; }
  h2 { color: #333; font-size: 24px; }
  table { font-size: 20px; width: 100%; }
  th { background-color: rgba(240,246,255,0.85); }
  pre { font-size: 16px; background: rgba(255,255,255,0.9); }
  pre code { color: #000 !important; }
  code { color: #000; }
  code span { color: #000 !important; }
  blockquote { font-size: 19px; border-left: 4px solid #0078d4; padding: 8px 16px; background: rgba(248,249,250,0.9); }
  strong { color: #0078d4; }
  footer { font-size: 12px; }
  header { font-size: 12px; }
  img { max-height: 420px; }
  td, th { background: rgba(255,255,255,0.85); }
---

<!-- _backgroundColor: #000 -->
<!-- _color: #fff -->
<!-- _header: "" -->
<!-- _footer: "" -->
<!-- _paginate: false -->

![bg cover](assets/cover.png)

---

# POC Objective

> **Prove** that we can provision a private Confluent Kafka cluster, create topics with proper access controls, and connect from AKS — via Terraform for infrastructure and Kafka CLI (from private network) for data-plane operations, with zero public internet exposure.

**Acceptance criteria:**

| # | Criteria |
|:-:|---------|
| 1 | Kafka cluster reachable **only** via PrivateLink (no public endpoint) |
| 2 | Topics created per team (`orders`, `payments`) with produce/consume ACLs |
| 3 | Per-team service accounts + API keys — least-privilege, team-scoped access |
| 4 | AKS cluster provisioned and able to reach Kafka privately |
| 5 | All secrets stored securely (Key Vault — not in code) |
| 6 | Run steps and verification steps documented |

---

# Scope

| In Scope | Out of Scope |
|----------|-------------|
| Confluent environment + Dedicated Kafka cluster | Production HA / multi-zone |
| PrivateLink networking (VNet + PE + DNS) | Performance testing |
| 2 topics, 1 service account, 1 API key, ACLs | Multi-region failover |
| AKS cluster provisioning | Application deployment (Helm) |
| Key Vault for secret storage | Schema Registry, Kafka Connect |
| Run steps + verification documentation | Monitoring & alerting |

> Everything out of scope is documented as a production consideration on the final slide.

---

# Architecture Overview

<!-- Replace with your diagram: docs/assets/architecture-overview.png -->
![bg right:55% contain](assets/architecture-hero.png)

**Split-architecture `terraform apply` (platform → app teams) creates:**

- Platform: Confluent Cloud environment, network, Kafka cluster
- Platform: Azure VNet, subnets, NSGs, Private Endpoint, Private DNS zone
- Platform: AKS cluster (private, workload identity)
- Platform: Key Vault with cluster metadata secrets
- App teams: Service accounts, API keys, topics, ACLs (per team)

**~25 resources total (platform ~20 + per-team ~5)**

---

# Network Design — PrivateLink

<!-- Replace with your diagram: docs/assets/network-privatelink.png -->
![bg right:55% contain](assets/network-privatelink.png)

**How Kafka is accessed privately:**

```
AKS Pod
  → CoreDNS
    → Azure Private DNS Zone
      → Private Endpoint (10.0.0.x)
        → PrivateLink (Azure backbone)
          → Confluent Kafka Broker
```

**Why PrivateLink:**
- Traffic **never** touches public internet
- No CIDR overlap risk (uses NAT)
- Azure-native (same pattern as SQL, Storage)
- Simpler than VNet peering

---

# Security Model


**Network layer:**
- PrivateLink — Kafka has no public endpoint
- Private AKS — API server has no public IP
- NSGs on all subnets

**Identity layer:**
- Confluent SA + cluster-scoped API key
- ACLs: topic-level produce/consume only
- AKS workload identity (OIDC — no stored creds)

**Secrets layer:**
- Key Vault with Azure RBAC
- No secrets in code, logs, or state outputs

---

# What Terraform Creates — Platform Team

**Deployed by:** Platform team (GitHub-hosted runner or local)
**Dependency chain (order matters):**

| # | Resource | Purpose |
|:-:|----------|----------|
| 1 | Confluent Environment | Logical container |
| 2 | Confluent Network | PrivateLink-enabled network |
| 3 | PL Access | Allow Azure subscription |
| 4 | Kafka Cluster | Dedicated, 1 CKU |
| 5 | Azure VNet + PE + DNS | Private connectivity |
| 6 | AKS Cluster | Private cluster + self-hosted runner |
| 7 | Key Vault | Stores cluster metadata (4 secrets) |

---

# What Terraform Creates — App Teams

**Deployed by:** Each app team (self-hosted runner on AKS — VNet access required)
**Reads cluster metadata from Key Vault, creates team-scoped resources:**

| # | Resource | Orders Team | Payments Team |
|:-:|----------|------------|---------------|
| 1 | Service Account | `sa-app-orders-poc-001` | `sa-app-payments-poc-001` |
| 2 | API Key | Cluster-scoped | Cluster-scoped |
| 3 | Topics | `orders` | `payments` |
| 4 | ACLs | WRITE+READ on own topics | WRITE+READ on own topics |
| 5 | KV Secrets | Writes `orders-confluent-api-key-*` | Writes `payments-confluent-api-key-*` |

> **Isolation:** Orders SA has zero access to payments topics and vice versa.

---

# What Terraform Creates — Azure

| Resource | Purpose |
|----------|---------|
| **Resource Group** | Container for all Azure resources |
| **VNet** (10.0.0.0/22) | Network boundary |
| **PE Subnet** (10.0.0.0/26) | Hosts the Private Endpoint |
| **AKS Subnet** (10.0.1.0/24) | Hosts AKS node pools |
| **NSGs** (×2) | Subnet-level traffic rules |
| **Private Endpoint** | Connects to Confluent via PrivateLink |
| **Private DNS Zone** | Resolves Kafka FQDN → PE private IP |
| **AKS Cluster** | Private cluster + workload identity + self-hosted runner |
| **Key Vault** | Integration point: platform writes cluster metadata, app teams write API keys |
| **Log Analytics** | Container Insights for AKS |

---

# AKS Cluster — How It's Provisioned

<!-- AKS provisioning diagram: docs/assets/aks-provisioning.png -->
![bg right:55% contain](assets/aks-provisioning.png)

**Private AKS with full hardening:**

| Feature | Setting |
|---------|---------|
| **API server** | Private only (no public FQDN) |
| **Auth** | Entra ID + Azure RBAC |
| **Local accounts** | Disabled |
| **Node pools** | System (1) + User (2) · D2s_v5 |
| **OS disk** | Managed (default; Ephemeral for prod) |
| **CNI** | Azure CNI (VNet-integrated pods) |
| **Network policy** | Calico |
| **Workload Identity** | OIDC issuer enabled |
| **Auto-upgrade** | Patch channel |

---

# How to Run — Prerequisites

| Task | Who | Time |
|------|-----|:----:|
| Create Azure storage account for TF state | Azure Admin | 5 min |
| Create service principal or managed identity | Azure Admin | 10 min |
| Register Azure providers (ContainerService, KeyVault, Network) | Azure Admin | 2 min |
| Create Confluent service account + cloud API key | Confluent Admin | 5 min |
| Set environment variables (`TF_VAR_*`) | Engineer | 5 min |

**Total one-time setup: ~30 minutes**

> Detailed commands in `docs/runbook.md` (Steps A–D)

---

# How to Run — Execution

```bash
# === Platform (GitHub-hosted runner or local) ===
cd terraform/platform

# 1. Initialize (configure backend for target environment)
terraform init -backend-config=backend-poc.hcl

# 2. Preview what will be created (~20 resources)
terraform plan -var-file=platform-poc.tfvars -out=tfplan

# 3. Create platform infrastructure
terraform apply tfplan

# === App Team (self-hosted runner in VNet) ===
cd ../teams/orders

# 4. Deploy topics + SA + ACLs (requires VNet access)
terraform init -backend-config=backend-poc.hcl
terraform plan -var-file=orders-poc.tfvars -out=tfplan
terraform apply tfplan

# 5. Verify (private cluster — uses ARM tunnel)
az aks command invoke \
  --resource-group rg-unpr-poc-001 \
  --name aks-unpr-poc-001 \
  --command "kubectl get nodes"
```

**Deploy time: ~1hr to 2hr** (Dedicated cluster takes longest)

---

# Proof: Kafka Cluster Exists

<!-- Replace with actual screenshot after deployment -->
![bg right:55% contain](assets/proof-kafka-cluster.png)

**What this proves:**
- Confluent environment created via Terraform
- Dedicated Kafka cluster (1 CKU) in westeurope
- PrivateLink networking enabled
- 2 topics created: `orders`, `payments`
- Service account + API key + ACLs configured

> Terraform output: `terraform output confluent_cluster_id`

---

# Proof: Private Endpoint Connected

<!-- Replace with actual screenshot after deployment -->
![bg right:55% contain](assets/proof-pe-approved.png)

**What this proves:**
- Private Endpoint created in Azure
- Connection status: **Approved**
- PrivateLink is active — Kafka reachable via private IP
- DNS zone resolves Kafka FQDN → 10.0.0.x (not public IP)

```bash
# Verify PE status
az network private-endpoint list \
  --resource-group $(terraform output -raw resource_group_name) \
  -o table
```

---

# Proof: AKS Cluster Exists

<!-- Replace with actual screenshot after deployment -->
![bg right:55% contain](assets/proof-aks-nodes.png)

**What this proves:**
- AKS cluster provisioned via Terraform
- Private cluster (API server not publicly exposed)
- 2 nodes in **Ready** state
- Workload identity enabled (OIDC issuer active)
- Entra ID + Azure RBAC for access control

```bash
az aks command invoke \
  --resource-group $RG --name $AKS \
  --command "kubectl get nodes"
```

---

# Proof: AKS Pod Can Do Nslookup To Kafka Endpoint

<!-- Replace with actual screenshot after deployment -->
![bg right:55% contain](assets/proof-of-connectivity.png)

**What this proves:**
- AKS pod can reach Kafka **privately** (via PrivateLink)
- **No public internet involved** in the data path

This is the core success criteria of the POC.
---

# Best Practices Applied

| Practice | What We Did | ADR |
|----------|------------|:---:|
| **Azure CAF naming** | All resources follow `<prefix>-<team>-<env>-<suffix>` via `azurecaf` provider | [005](02-design/decisions/005-azure-caf-naming.md) |
| **Private AKS cluster** | API server has no public IP — access via `az aks command invoke` | [007](02-design/decisions/007-private-aks-cluster.md) |
| **Workload Identity** | AKS pods authenticate to Key Vault via OIDC — no stored secrets | [003](02-design/decisions/003-workload-identity-for-secrets.md) |
| **Key Vault RBAC** | Azure RBAC (not access policies) — auditable, consistent | [004](02-design/decisions/004-keyvault-rbac-over-access-policies.md) |
| **Azure CNI** | Every pod gets a VNet IP — direct PE routing, no NAT | [006](02-design/decisions/006-azure-cni-for-aks.md) |
| **Calico network policy** | Pod-to-pod traffic control (production-ready engine) | [008](02-design/decisions/008-calico-network-policy.md) |
| **Split architecture** | Platform creates cluster; app teams create topics from VNet | [009](02-design/decisions/009-monorepo-platform-teams-split.md) |
| **Reusable workflows** | Single plan/apply template, thin callers per deployment | — |
| **Multi-env tfvars** | Same `.tf` code, different `*-poc.tfvars` + `backend-poc.hcl` per env | — |
| **State file** | Remote backend (Azure Storage), versioned, encrypted, TLS 1.2 | — |
| **Sensitive outputs** | 5 outputs marked `sensitive = true` — never leaked in logs | — |

> Each ADR documents context, alternatives considered, and trade-offs.

# POC Outcome

| What We Proved | Result |
|----------------|:------:|
| Private Kafka cluster provisioned via Terraform | ✅ |
| Zero public internet exposure (PrivateLink) | ✅ |
| Topics + SA + ACLs created automatically | ✅ |
| AKS cluster provisioned via Terraform | ✅ |
| AKS can do nslookup via private path  | ✅ |
| Secrets in Key Vault (not in code) | ✅ |
| Split architecture: platform + app teams (~20 min + ~5 min) | ✅ |

**All acceptance criteria met.**

> **Recommendation:** Pattern is proven. Ready for production design phase.

---

# If Approved: Production Considerations

| Area | What to Add | Priority |
|------|------------|:--------:|
| High availability | Multi-zone AKS, 3+ CKUs | P1 |
| CI/CD pipeline | GitHub Actions / Azure DevOps with OIDC | P1 |
| Disable local accounts | Enforce Entra-ID-only AKS auth | P1 |
| Observability | Confluent metrics + Azure Monitor alerts | P2 |
| Secret rotation | Key Vault + Confluent API key lifecycle | P2 |
| Policy-as-code | OPA / Sentinel for governance | P3 |
| Performance testing | Throughput baseline before go-live | P3 |

> These are all documented in `docs/` for the production design phase.

---

<!-- _header: "" -->
<!-- _footer: "" -->
<!-- _paginate: false -->

# 📂 Documentation Navigation

| 1 | [Runbook](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/04-runsteps-and-verification/runbook.md) | Prerequisites, execution steps, verification (V1–V10), cleanup |
| 2 | [Architecture](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/architecture.md) | Full system design + resource diagram |
| 3 | [Network Design](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/network-design.md) | PrivateLink, DNS flow, IP plan, subnet sizing |
| 4 | [Security & Permissions](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/security-and-permissions.md) | Identity model, RBAC, secrets |
| 5 | [ADR-001: Dedicated Kafka](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/001-dedicated-kafka-tier.md) | Why Dedicated over Basic/Standard |
| 6 | [ADR-002: PrivateLink](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/002-privatelink-connectivity.md) | Why PrivateLink over VNet peering |
| 7 | [ADR-003: Workload Identity](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/003-workload-identity-for-secrets.md) | OIDC federation for Key Vault |
| 8 | [ADR-004: Key Vault RBAC](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/004-keyvault-rbac-over-access-policies.md) | RBAC over access policies |
| 9 | [ADR-005: Azure CAF Naming](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/005-azure-caf-naming.md) | Consistent naming via azurecaf |
| 10 | [ADR-006: Azure CNI](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/006-azure-cni-for-aks.md) | VNet-integrated pods |
| 11 | [ADR-007: Private AKS](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/007-private-aks-cluster.md) | No public API server |
| 12 | [ADR-008: Calico](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/008-calico-network-policy.md) | Network policy engine |
| 13 | [ADR-009: Split Architecture](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/02-design/decisions/009-monorepo-platform-teams-split.md) | Monorepo with platform/teams split |
| 14 | [Terraform Modules](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/03-implementation/terraform-modules.md) | Module design, variables, validation |
| 14 | [Resource Details](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/03-implementation/resource-details.md) | All provisioned resources |
| 15 | [Issues & Resolutions](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/05-observations/issues-and-resolutions.md) | Problems encountered + fixes |
| 16 | [Future Improvements](https://github.com/GouthamKumar4/terraform-confluent-cloud-aks-poc/blob/main/docs/05-observations/future-improvements.md) | Production roadmap |
