# ADR-007: Private AKS Cluster

**Status:** Proposed
**Date:** May 2026
**Reviewer:** _(pending)_

## Context

AKS API server can be configured in three modes:

| Mode | API Server Access | Management Access |
|------|-------------------|-------------------|
| **Public** | Internet (optionally IP-restricted) | Direct `kubectl` from anywhere |
| **Public + Authorized IPs** | Only from listed CIDRs | `kubectl` from allowed IPs |
| **Private** | VNet only (no public endpoint) | Requires VNet access (VPN/Bastion/command invoke) |

The POC principle is: **no public endpoints for any component** (Kafka is PrivateLink-only, Key Vault is deny-by-default).

## Decision

Enable **private cluster** (`private_cluster_enabled = true`) — the AKS API server gets a private IP only. No public FQDN.

## Consequences

### Positive
- **Consistent security posture** — all components (Kafka, Key Vault, AKS API) are private
- **No attack surface** — API server unreachable from internet, immune to brute-force/credential stuffing
- **Compliance-friendly** — meets "no public endpoints" policies common in enterprise environments
- **Private DNS integration** — API server FQDN resolves to private IP within VNet

### Negative
- **No direct `kubectl`** — cannot run `kubectl` from a developer laptop without VNet access
- **Debugging complexity** — must use `az aks command invoke` (tunnels through ARM API) or VPN/Bastion
- **CI/CD limitation** — GitHub-hosted runners can't reach API server directly (use `command invoke` or self-hosted runners)
- **Slightly slower management** — `command invoke` adds latency vs direct `kubectl`

### How We Manage a Private Cluster in This POC

| Task | Method |
|------|--------|
| Run `kubectl` commands | `az aks command invoke --command "kubectl ..."` |
| Deploy test pods | `az aks command invoke` |
| Debug networking | `az aks command invoke --command "kubectl exec ..."` |
| CI/CD (future) | Self-hosted runner in VNet, OR `az aks command invoke` in pipeline |

### Production Alternatives for Management Access

| Option | How | Best For |
|--------|-----|----------|
| `az aks command invoke` | ARM tunnel (no VNet needed) | POC, quick debugging |
| Azure Bastion | Jump host in VNet | Interactive sessions |
| VPN Gateway | Site-to-site or P2S VPN | Persistent dev access |
| Self-hosted runners | GitHub runner in VNet | CI/CD pipelines |
| Private endpoint for API | API server on PE in hub VNet | Hub-spoke architectures |

