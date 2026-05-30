# ADR-006: Azure CNI for AKS Networking

**Status:** Proposed
**Date:** May 2026
**Reviewer:** _(pending)_

## Context

AKS supports multiple networking models (CNI plugins):

| Plugin | Pod IP Source | VNet Integration | Performance |
|--------|-------------|:----------------:|:-----------:|
| **Kubenet** | Bridge network (NAT'd) | ❌ Pods not directly on VNet | Lower overhead |
| **Azure CNI (traditional)** | VNet subnet IPs | ✅ Every pod gets a VNet IP | Native performance |
| **Azure CNI Overlay** | Overlay network | ⚠️ Partial (node IPs on VNet, pod IPs not) | Good |
| **Azure CNI + Cilium** | VNet IPs + eBPF | ✅ Full + advanced observability | Best |

For this POC, pods need to reach the **Private Endpoint** (10.0.1.x) to access Kafka. The PE is on the VNet, so pods must be able to route to VNet IPs.

## Decision

Use **Azure CNI (traditional)** — every pod gets an IP from the AKS subnet (`10.0.1.0/24`).

## Consequences

### Positive
- **Direct VNet routing** — pods can reach the Private Endpoint without NAT or UDR
- **No IP masquerading** — NSGs and flow logs show actual pod IPs
- **Azure-native** — standard for enterprise AKS deployments
- **PrivateLink compatible** — pods resolve and connect to PE IP directly
- **Simpler debugging** — `kubectl get pod -o wide` shows real VNet IPs

### Negative
- **IP consumption** — each pod consumes a VNet IP (max 250 pods/node × nodes). Subnet must be sized appropriately
- **Larger subnet needed** — /24 (251 IPs) for 2 nodes provides headroom for Azure CNI
- **Slower pod startup** — each pod waits for Azure to assign a NIC IP (milliseconds, not noticeable)

### Why Not Kubenet?
Kubenet uses a bridge network with NAT. Pods get IPs from a pod CIDR (not the VNet). To reach the Private Endpoint, traffic would need UDR (User Defined Routes) on the AKS subnet pointing pod traffic to the node. This adds complexity and is not recommended for PrivateLink scenarios.

### Why Not Azure CNI Overlay?
Overlay mode puts pod IPs in a separate address space — pods can still reach VNet resources via the node's VNet IP, but NSG/flow-log visibility is reduced. For a POC where simplicity and debuggability matter, traditional CNI is preferred.

### IP Planning

| Component | Calculation | IPs Needed |
|-----------|------------|:----------:|
| System pool: 1 node × 30 max pods | 1 + 30 | 31 |
| User pool: 2 nodes × 30 max pods | 2 + 60 | 62 |
| Azure reserved (5 per subnet) | — | 5 |
| **Total** | | **98** |
| **Subnet /24** | | **251 available** ✅ |

