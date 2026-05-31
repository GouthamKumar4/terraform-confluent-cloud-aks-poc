# Future Improvements

> Items identified during the POC that are **out of scope** but recommended for production.

---

## Priority Matrix

| # | Improvement | Category | Effort | Impact | Priority |
|---|-------------|----------|:------:|:------:|:--------:|
| ~~1~~ | ~~OIDC for CI/CD authentication~~ | ~~Security~~ | — | — | ✅ Done |
| 2 | Workload Identity per pod | Security | Medium | 🔴 High | P1 |
| 3 | Secret rotation automation | Security | High | 🔴 High | P2 |
| 4 | tflint + tfsec in CI/CD | Quality | Low | 🟠 Medium | P2 |
| 5 | Policy-as-code (OPA/Sentinel) | Governance | High | 🟠 Medium | P2 |
| 6 | Multi-zone PrivateLink | Reliability | Medium | 🟠 Medium | P2 |
| 7 | Observability stack | Operations | Medium | 🔴 High | P2 |
| 8 | Key Vault private endpoint | Security | Low | 🟡 Low | P3 |
| 9 | Cost optimization (CKU right-sizing) | Cost | Low | 🟡 Low | P3 |

---
## Improvement Details

### 1. ~~OIDC for CI/CD Authentication~~ — ✅ Implemented

**Status:** Done in POC.
**What was done:** Managed Identity (`id-terraform-unpr-poc-001`) with OIDC federated credentials for GitHub Actions. No `ARM_CLIENT_SECRET` exists anywhere — workflows use `ARM_USE_OIDC=true` with `id-token: write` permission.

**Remaining for production:**
- Use `azure/login@v2` action for explicit login step (optional, cleaner logs)
- Scope Managed Identity roles to resource group instead of subscription

---

### 2. Workload Identity per Pod

**Current state:** AKS kubelet identity (node-level) has Key Vault Secrets User role. All pods on all nodes can read all secrets.
**Target state:** Per-service-account federated identity — each pod gets only the secrets it needs.

**Why it matters:** Blast radius reduction. If a pod is compromised, it can only access its own secrets.

**Implementation:**
1. Create user-assigned managed identity per application
2. Create Kubernetes ServiceAccount with annotation: `azure.workload.identity/client-id`
3. Create federated credential linking SA ↔ MI via OIDC issuer
4. Assign `Key Vault Secrets User` to the MI (scoped to specific secrets)

---

### 3. Secret Rotation Automation

**Current state:** Confluent API keys are static — no rotation.
**Target state:** Automated rotation using Azure Event Grid + Azure Functions.

**Flow:**
```
Key Vault near-expiry event → Event Grid → Azure Function → 
  1. Create new Confluent API key
  2. Update Key Vault secret
  3. Delete old Confluent API key
```

---

### 4. tflint + tfsec in CI/CD

**Current state:** CI/CD runs `terraform fmt` + `terraform validate` only.
**Target state:** Add static analysis:
- **tflint** — catches deprecated arguments, unused variables, naming issues
- **tfsec** / **trivy** — detects security misconfigurations (e.g., missing encryption, overly permissive NSGs)

**Implementation:** Add steps to `terraform-validate.yml` workflow.

---

### 5. Policy-as-Code (OPA/Sentinel)

**Current state:** No policy enforcement.
**Target state:** OPA Gatekeeper on AKS + Sentinel/OPA for Terraform plan validation.

**Examples:**
- All Key Vaults must have purge protection
- All AKS clusters must be private
- No public IPs on any resource
- All resources must have required tags

---

### 6. Multi-Zone PrivateLink

**Current state:** Single Private Endpoint in zone 1.
**Target state:** Private Endpoints in all 3 availability zones for HA.

**Implementation:** The networking module already supports `confluent_private_link_service_aliases` as a map — iterate over zones to create multiple PEs.

---

### 7. Observability Stack

**Current state:** Log Analytics workspace exists, AKS Container Insights enabled. No Kafka metrics.
**Target state:**
- Confluent Cloud metrics exported to Azure Monitor
- AKS pod-level Kafka client metrics (JMX → Prometheus → Azure Managed Grafana)
- Alerting on: consumer lag, connection failures, Key Vault access denied

---

### 8. Key Vault Private Endpoint

**Current state:** Key Vault accessible from allowed IPs + AzureServices bypass.
**Target state:** Key Vault with its own Private Endpoint in the VNet — no public access at all.

---

### 9. Cost Optimization

**Current state:** 1 CKU, single-zone, 2x D2s_v5 nodes.
**Target state:** Right-size based on actual throughput during load testing.

| Component | POC Cost | Production Estimate |
|-----------|---------|-------------------|
| Confluent Dedicated 1 CKU | ~$1,080/mo | Based on throughput needs |
| AKS 2x D2s_v5 | ~$140/mo | Based on pod density |
| Key Vault (Standard) | ~$3/mo | Same |
| Private Endpoint | ~$7/mo | × zones |
| Storage (TF state) | ~$1/mo | Same |

---

## Items NOT Recommended for POC

These were explicitly kept out of scope to maintain focus:

| Item | Reason |
|------|--------|
| Schema Registry | Not needed for basic produce/consume validation |
| Kafka Connect | No source/sink integration required |
| Multi-region cluster | DR pattern is a separate architecture |
| Load testing | Requires production cluster sizing |
| Application deployment (Helm charts) | POC validates infrastructure, not application |
| Azure Firewall | Network egress control is production concern |
| Azure Bastion | Only needed if private AKS API access required outside CI/CD |
