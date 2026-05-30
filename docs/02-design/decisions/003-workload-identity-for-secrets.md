# ADR-003: Use Workload Identity for Key Vault Access

**Status:** Proposed
**Date:** May 2026
**Reviewer:** _(pending)_

## Context

AKS pods need to read secrets from Azure Key Vault (Confluent API key, endpoint). There are several ways to provide Azure credentials to pods:

| Method | How It Works | Security |
|--------|-------------|----------|
| **Hardcoded secrets** | Mount secrets as env vars / volumes in pod spec | ❌ Worst — secrets in YAML |
| **Kubernetes Secrets** | Store in etcd, mount in pods | ⚠️ Better — but not encrypted at rest by default |
| **Pod Identity (v1)** | Assign Managed Identity to pods via CRD | ⚠️ Deprecated by Microsoft |
| **Workload Identity** | OIDC federation — pod gets token from AAD via projected service account | ✅ Best — no stored credentials |

## Decision

Enable **Workload Identity** on the AKS cluster (`oidc_issuer_enabled = true`, `workload_identity_enabled = true`).

For the POC, use the **kubelet identity** (system-assigned managed identity) for Key Vault access. In production, migrate to per-pod Workload Identity with federated credentials.

## Consequences

### Positive
- **No stored credentials** — pods authenticate via OIDC token exchange, not stored secrets
- **Azure-native** — Microsoft's recommended approach for AKS-to-Azure-service auth
- **Auditable** — all access logged in Azure AD sign-in logs
- **Granular** — can assign different identities per service/namespace
- **Rotation-free** — no secrets to rotate on the AKS side

### Negative
- **Complexity** — requires OIDC issuer, federated credential, service account annotation
- **POC shortcut** — POC uses kubelet identity (node-level), not per-pod identity
- **Learning curve** — team needs to understand OIDC federation model

### POC vs Production

| Aspect | POC | Production |
|--------|-----|-----------|
| Identity scope | Kubelet (all pods on node) | Per-pod via federated SA |
| Credential type | System-assigned MI | User-assigned MI per service |
| Key Vault access | All pods can read all secrets | Namespace-scoped access |
