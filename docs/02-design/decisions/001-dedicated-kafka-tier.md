# ADR-001: Use Dedicated Kafka Tier

**Status:** Proposed
**Date:** May 2026
**Reviewer:** _(pending)_

## Context

Confluent Cloud offers three Kafka cluster tiers:

| Tier | PrivateLink Support | SLA | Cost |
|------|:-------------------:|-----|------|
| Basic | ❌ No | 99.5% | ~$0.04/hr |
| Standard | ❌ No | 99.95% | ~$0.22/hr |
| **Dedicated** | ✅ Yes | 99.95%+ | ~$1.50/hr per CKU |

The POC requirement is **private-only** Kafka access — no public endpoint. PrivateLink is the only Confluent-supported mechanism for private connectivity from Azure.

## Decision

Use the **Dedicated** tier (1 CKU, single-zone) for the POC Kafka cluster.

## Consequences

### Positive
- Enables PrivateLink (mandatory for private access)
- Dedicated compute — no noisy-neighbor risk
- Supports custom networking configurations
- Production-representative architecture

### Negative
- **Cost:** ~$1.50/hr (~$36/day) — significantly more than Basic/Standard
- **Provisioning time:** 15-30 minutes (longer than shared tiers)
- Must teardown immediately after demo to control costs

### Mitigations
- POC uses 1 CKU (minimum) and single-zone (cheapest Dedicated option)
- Runbook includes explicit teardown steps
- CI/CD workflow uses manual dispatch to prevent accidental applies
