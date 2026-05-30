# ADR-002: Use PrivateLink over VNet Peering

**Status:** Proposed
**Date:** May 2026
**Reviewer:** _(pending)_

## Context

To connect Azure workloads to Confluent Cloud Kafka privately, three options exist:

| Option | How It Works | Confluent Support |
|--------|-------------|:-----------------:|
| **PrivateLink** | Private Endpoint in your VNet → Confluent's Private Link Service | ✅ Officially supported |
| **VNet Peering** | Peer your VNet with Confluent's VNet | ✅ Supported (Enterprise only) |
| **Transit Gateway** | Hub-spoke via gateway | ❌ Azure: N/A (AWS concept) |

## Decision

Use **Azure PrivateLink** for private connectivity between AKS and Confluent Kafka.

## Consequences

### Positive
- **No network overlap risk** — PrivateLink uses NAT, so CIDR ranges don't need to be unique across organizations
- **Simpler setup** — one Private Endpoint + DNS zone, no peering negotiation
- **Azure-native** — standard pattern for PaaS private access (same as Storage, SQL, etc.)
- **Security** — traffic stays on Azure backbone, never touches public internet
- **Supported on Dedicated tier** — which the POC already requires

### Negative
- **Unidirectional** — Confluent cannot initiate connections back to your VNet (not needed for Kafka)
- **Cost** — Private Endpoint has a small hourly cost (~$0.01/hr)
- **DNS complexity** — requires Private DNS Zone + A record for FQDN resolution

### Alternatives Considered
- **VNet Peering:** Requires Enterprise tier (even more expensive), CIDR coordination with Confluent, and bilateral peering approval. Overkill for this use case.
- **Public endpoint + IP allowlist:** Violates the "private-only" requirement. Traffic traverses the internet.
