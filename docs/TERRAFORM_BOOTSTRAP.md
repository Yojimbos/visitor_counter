# Terraform Bootstrap Setup Guide

This guide describes how to bootstrap the Terraform backend and then apply the main infrastructure safely.

## Why Bootstrap Exists

The main Terraform configuration expects an Azure backend, but that backend storage account must exist before `terraform init` can use it.

## Phase 1: Create Backend Storage

From [infra/terraform/bootstrap](/c:/repositories/visitor_counter/infra/terraform/bootstrap):

```powershell
terraform init
terraform apply -target="azurerm_resource_group.rg" -target="azurerm_storage_account.tfstate" -target="azurerm_storage_container.tfstate" -target="azurerm_management_lock.storage_account_lock"
```

This creates:

- resource group `visitor-counter-rg`
- storage account `visitorcounterstate`
- blob container `tfstate`
- a delete lock for the state storage account

## Phase 2: Initialize Main Terraform

From [infra/terraform](/c:/repositories/visitor_counter/infra/terraform):

```powershell
terraform import azurerm_resource_group.rg /subscriptions/63648506-5811-44a1-958b-1a438c60f9b6/resourceGroups/visitor-counter-rg
terraform init
terraform plan
```

## Phase 3: Apply Main Infrastructure

```powershell
terraform apply
```

The main stack provisions:

- Azure Container Registry
- Azure Kubernetes Service
- Azure Key Vault
- Azure Database for PostgreSQL Flexible Server
- backup Blob Storage for weekly logical dumps
- virtual network and subnets

## Current Database and Backup Posture

- PostgreSQL backup retention is explicitly set to 7 days.
- Geo-redundant PostgreSQL backup support is codified behind `postgres_geo_redundant_backup_enabled`, but it is currently off because Azure applies it at server creation time.
- PostgreSQL private networking support is codified behind `postgres_private_network_enabled`, but it is currently off.
- Weekly logical backups are stored in Azure Blob Storage with `GRS` replication and lifecycle cleanup.

## Important Variables

See [infra/terraform/variables.tf](/c:/repositories/visitor_counter/infra/terraform/variables.tf:1) for the current defaults, especially:

- `aks_node_count`
- `postgres_backup_retention_days`
- `postgres_geo_redundant_backup_enabled`
- `postgres_private_network_enabled`
- `backup_storage_replication_type`
- `logical_backup_retention_days`

## CI Note

The CI Terraform workflow uses import logic for existing Azure resources so repeated runs do not fail on already-created infrastructure.

## Troubleshooting

If `terraform init` fails before the backend exists:

1. Run the bootstrap phase first.
2. Confirm the storage account and container were created.

If `terraform plan` fails on existing Azure resources:

1. Check the Terraform workflow import logic.
2. Confirm the target resource names still match the current Azure environment.
