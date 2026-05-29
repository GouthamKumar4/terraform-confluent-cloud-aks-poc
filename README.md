# Private Confluent Cloud Kafka + AKS — Terraform POC

## Overview

This repository provisions a **private** Confluent Cloud Kafka cluster with topics, service account, API key, ACLs, and an AKS cluster — all via Terraform. Sensitive outputs are stored in Azure Key Vault.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Azure Subscription                  │
│                                                       │
│  ┌──────────────┐    PrivateLink     ┌────────────┐ │
│  │  VNet        │◄──────────────────►│ Confluent  │ │
│  │  ├─ PE Subnet│    (private)       │ Cloud      │ │
│  │  └─ AKS Sub  │                    │ Kafka      │ │
│  └──────┬───────┘                    └────────────┘ │
│         │                                             │
│  ┌──────▼───────┐         ┌────────────────┐        │
│  │  AKS Cluster │────────►│  Key Vault     │        │
│  │  (workload   │  reads  │  (API key,     │        │
│  │   identity)  │  secrets│   secret,      │        │
│  └──────────────┘         │   endpoint)    │        │
│                            └────────────────┘        │
└─────────────────────────────────────────────────────┘
```

## Repository Structure

```
├── .github/workflows/       # CI/CD pipelines
│   ├── terraform-validate.yml
│   ├── terraform-plan.yml
│   └── terraform-apply.yml
├── terraform/
│   ├── environments/poc/    # Root module for POC
│   └── modules/
│       ├── confluent/       # Kafka cluster, topics, ACLs
│       ├── networking/      # VNet, PrivateLink, DNS
│       ├── aks/             # AKS cluster
│       └── keyvault/        # Secret storage
└── docs/                    # Documentation
```

## Prerequisites

- Terraform >= 1.5
- Azure CLI authenticated (`az login`)
- Confluent Cloud org-level API key
- Azure subscription with PrivateLink capability
- Azure Storage account for Terraform state backend

## Quick Start

```bash
cd terraform/environments/poc

# Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars

# Set sensitive vars via environment
export TF_VAR_confluent_cloud_api_key="your-key"
export TF_VAR_confluent_cloud_api_secret="your-secret"

# Initialize and deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Cleanup

```bash
terraform destroy
```

## Documentation

- [Architecture](docs/architecture.md)
- [Runbook](docs/runbook.md)
- [Presentation](docs/presentation.md) — export to PPTX: `marp docs/presentation.md --pptx`
- [Executive Summary](docs/executive-summary.md)

## Security

- All Kafka access is via PrivateLink (no public endpoint)
- API keys stored in Azure Key Vault with RBAC
- AKS uses workload identity for Key Vault access
- Terraform state should be in encrypted Azure Storage backend
- No secrets committed to source control
