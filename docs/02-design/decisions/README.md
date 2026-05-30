# Architecture Decision Records (ADRs)

> Architectural choices made during this POC and the reasoning behind them.

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [001](001-dedicated-kafka-tier.md) | Use Dedicated Kafka tier | Proposed | May 2026 |
| [002](002-privatelink-connectivity.md) | Use PrivateLink over VNet Peering | Proposed | May 2026 |
| [003](003-workload-identity-for-secrets.md) | Use Workload Identity for Key Vault access | Proposed | May 2026 |
| [004](004-keyvault-rbac-over-access-policies.md) | Use Key Vault RBAC over access policies | Proposed | May 2026 |
| [005](005-azure-caf-naming.md) | Use Azure CAF naming convention | Proposed | May 2026 |
| [006](006-azure-cni-for-aks.md) | Azure CNI for AKS networking | Proposed | May 2026 |
| [007](007-private-aks-cluster.md) | Private AKS cluster (no public API) | Proposed | May 2026 |
| [008](008-calico-network-policy.md) | Calico network policy engine | Proposed | May 2026 |

## ADR Format

Each ADR follows the [Michael Nygard format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions):

1. **Title** — Short descriptive name
2. **Status** — Proposed / Accepted / Deprecated / Superseded
3. **Context** — What is the issue we're facing?
4. **Decision** — What did we decide?
5. **Consequences** — What are the trade-offs?
