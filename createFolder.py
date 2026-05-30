"""
Script to recreate the POC project folder and file structure.
Creates all directories and empty placeholder files.
Binary files (images, PDFs, PPTX, terraform providers) are skipped.
"""

import os

BASE_DIR = "./"

DIRECTORIES = [
    ".github/workflows",
    "docs/01-planning",
    "docs/02-design/decisions",
    "docs/03-implementation",
    "docs/04-runsteps-and-verification",
    "docs/05-observations",
    "docs/assets",
    "terraform/environments/poc/.terraform/modules",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/aztfmod/azurecaf/1.2.34/linux_amd64",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/confluentinc/confluent/2.73.0/linux_amd64",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/hashicorp/azurerm/4.74.0/linux_amd64",
    "terraform/modules/aks",
    "terraform/modules/confluent",
    "terraform/modules/keyvault",
    "terraform/modules/networking",
]

FILES = [
    # Root
    ".gitignore",
    "CHANGELOG.md",
    "context.md",
    "README.md",
    "runsteps.md",

    # GitHub workflows
    ".github/workflows/terraform-apply.yml",
    ".github/workflows/terraform-plan.yml",
    ".github/workflows/terraform-validate.yml",

    # Docs
    "docs/architecture.md",
    "docs/executive-summary.md",
    "docs/presentation.html",
    "docs/presentation.md",
    "docs/presentation.md.bak",

    # Docs - planning
    "docs/01-planning/naming-conventions.md",
    "docs/01-planning/scope-and-objectives.md",

    # Docs - design
    "docs/02-design/network-design.md",
    "docs/02-design/security-and-permissions.md",
    "docs/02-design/decisions/001-dedicated-kafka-tier.md",
    "docs/02-design/decisions/002-privatelink-connectivity.md",
    "docs/02-design/decisions/003-workload-identity-for-secrets.md",
    "docs/02-design/decisions/004-keyvault-rbac-over-access-policies.md",
    "docs/02-design/decisions/005-azure-caf-naming.md",
    "docs/02-design/decisions/006-azure-cni-for-aks.md",
    "docs/02-design/decisions/007-private-aks-cluster.md",
    "docs/02-design/decisions/008-calico-network-policy.md",
    "docs/02-design/decisions/README.md",

    # Docs - implementation
    "docs/03-implementation/resource-details.md",
    "docs/03-implementation/terraform-modules.md",

    # Docs - runsteps and verification
    "docs/04-runsteps-and-verification/cicd.md",
    "docs/04-runsteps-and-verification/runbook.md",

    # Docs - observations
    "docs/05-observations/future-improvements.md",
    "docs/05-observations/issues-and-resolutions.md",

    # Terraform - environments/poc
    "terraform/environments/poc/.terraform.lock.hcl",
    "terraform/environments/poc/backend.tf",
    "terraform/environments/poc/locals.tf",
    "terraform/environments/poc/main.tf",
    "terraform/environments/poc/outputs.tf",
    "terraform/environments/poc/poc.tfvars",
    "terraform/environments/poc/providers.tf",
    "terraform/environments/poc/tfplan",
    "terraform/environments/poc/variables.tf",
    "terraform/environments/poc/versions.tf",

    # Terraform - .terraform internals
    "terraform/environments/poc/.terraform/terraform.tfstate",
    "terraform/environments/poc/.terraform/modules/modules.json",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/aztfmod/azurecaf/1.2.34/linux_amd64/CHANGELOG.md",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/aztfmod/azurecaf/1.2.34/linux_amd64/LICENSE",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/aztfmod/azurecaf/1.2.34/linux_amd64/README.md",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/aztfmod/azurecaf/1.2.34/linux_amd64/terraform-provider-azurecaf_v1.2.34",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/confluentinc/confluent/2.73.0/linux_amd64/LICENSE",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/confluentinc/confluent/2.73.0/linux_amd64/README.md",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/confluentinc/confluent/2.73.0/linux_amd64/terraform-provider-confluent_2.73.0",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/hashicorp/azurerm/4.74.0/linux_amd64/LICENSE.txt",
    "terraform/environments/poc/.terraform/providers/registry.terraform.io/hashicorp/azurerm/4.74.0/linux_amd64/terraform-provider-azurerm_v4.74.0_x5",

    # Terraform - modules
    "terraform/modules/aks/main.tf",
    "terraform/modules/aks/outputs.tf",
    "terraform/modules/aks/variables.tf",
    "terraform/modules/confluent/main.tf",
    "terraform/modules/confluent/outputs.tf",
    "terraform/modules/confluent/variables.tf",
    "terraform/modules/confluent/versions.tf",
    "terraform/modules/keyvault/main.tf",
    "terraform/modules/keyvault/outputs.tf",
    "terraform/modules/keyvault/variables.tf",
    "terraform/modules/networking/main.tf",
    "terraform/modules/networking/outputs.tf",
    "terraform/modules/networking/variables.tf",
]


def create_structure(base_path: str) -> None:
    # Create directories
    for d in DIRECTORIES:
        path = os.path.join(base_path, d)
        os.makedirs(path, exist_ok=True)
        print(f"DIR  {path}")

    # Create files
    for f in FILES:
        path = os.path.join(base_path, f)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if not os.path.exists(path):
            with open(path, "w") as fh:
                fh.write("")
            print(f"FILE {path}")
        else:
            print(f"SKIP {path} (already exists)")


if __name__ == "__main__":
    create_structure(BASE_DIR)
    print("\nDone! Structure created under:", os.path.abspath(BASE_DIR))
