# ADR-008: Calico Network Policy for AKS

**Status:** Proposed
**Date:** May 2026
**Reviewer:** _(pending)_

## Context

AKS supports multiple network policy engines to control pod-to-pod and pod-to-external traffic:

| Engine | Scope | Features | Overhead |
|--------|-------|----------|:--------:|
| **None** | No enforcement | — | None |
| **Azure Network Policy** | L3/L4 only | Basic ingress/egress rules | Low |
| **Calico** | L3/L4 + advanced | Global policies, DNS policies, host protection, logging | Medium |
| **Cilium** | L3/L4/L7 + eBPF | All of Calico + L7 visibility, service mesh | Higher |

## Decision

Use **Calico** as the network policy engine (`network_policy = "calico"`).

## Consequences

### Positive
- **Industry standard** — most widely used Kubernetes network policy engine
- **Granular control** — can restrict pod-to-pod, pod-to-external, and pod-to-service traffic
- **GlobalNetworkPolicy** — cluster-wide rules (e.g., "deny all egress except DNS + PE subnet")
- **No extra cost** — included in AKS, managed by Microsoft
- **Future-ready** — enables production hardening without cluster recreation

### Negative
- **Slightly more resource usage** — Calico DaemonSet runs on every node
- **Complexity** — more powerful = more things to configure (but can start with no policies)
- **Not used in POC** — we enable Calico but don't define custom NetworkPolicy resources yet

### Why Enable It Now (Even Without Custom Policies)?

Network policy engine is an **immutable cluster setting** — you cannot change it after cluster creation. By enabling Calico now:
1. The POC cluster is production-representative
2. Reviewers can validate that the engine is ready
3. Custom policies can be added without recreating the cluster

### Example: Production Network Policy (Not Implemented in POC)

```yaml
# Restrict Kafka consumer pods to only reach PE subnet + DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kafka-consumer-egress
  namespace: kafka-apps
spec:
  podSelector:
    matchLabels:
      app: kafka-consumer
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/26    # PE subnet (Kafka via PrivateLink)
      ports:
        - port: 9092
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - port: 53
          protocol: UDP
```

