# Terraform Bootstrap Setup Guide

This guide explains how to properly initialize the Terraform infrastructure from scratch.

## Problem
The `backend.tf` references Azure resources (storage account, resource group) that don't exist yet, causing `terraform init` to fail.

## Solution: 3-Phase Bootstrap Process

### Phase 1: Bootstrap backend storage in a separate folder

**Step 1.1**: Use the bootstrap folder so the main Terraform files are not loaded together
```powershell
cd infra/terraform/bootstrap
terraform init
```

Expected output: Terraform initialized successfully in the bootstrap folder

**Step 1.2**: Create bootstrap resources (storage account + resource group only)
```powershell
terraform apply -target="azurerm_resource_group.rg" -target="azurerm_storage_account.tfstate" -target="azurerm_storage_container.tfstate" -target="azurerm_management_lock.storage_account_lock"
```

This creates:
- Resource group: `visitor-counter-rg`
- Storage account: `visitorcounterstate`
- Storage container: `tfstate`
- Delete lock on storage account (prevents accidental deletion)

**Approve**: Type `yes` when prompted

### Phase 2: Migrate to Remote State

**Step 2.1**: Import the existing resource group into Terraform state
```powershell
cd ..
terraform import azurerm_resource_group.rg /subscriptions/63648506-5811-44a1-958b-1a438c60f9b6/resourceGroups/visitor-counter-rg
```

This imports the resource group created during bootstrap into the main Terraform state.

**Step 2.2**: Remove local state if it exists
```powershell
Remove-Item -Path terraform.tfstate* -Force
```

**Step 2.3**: Reinitialize Terraform with the existing remote backend
```powershell
terraform init
```

### Phase 3: Deploy Full Infrastructure

Now all resources can be deployed:

**Step 3.1**: Plan the deployment
```powershell
terraform plan -out=tfplan
```

Review the outputs. You should see all resources being created:
- AKS Cluster
- PostgreSQL Server
- Container Registry
- Key Vault
- Virtual Network with subnets
- RBAC assignments

**Step 3.2**: Apply the full infrastructure
```powershell
terraform apply tfplan
```

Expected output: All resources created successfully

**Step 3.3**: Verify deployment
```powershell
terraform output
```

This shows:
- ACR login server
- AKS cluster name and ID
- PostgreSQL FQDN
- Key Vault name
- All secrets are securely stored in Key Vault

## Architecture Overview

After successful deployment:

```
┌─────────────────────────────────────┐
│   Azure Resource Group              │
│   visitor-counter-rg                │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ VirtualNetwork (10.0.0.0/16)  │ │
│  │                               │ │
│  │ ┌─────────────────────────┐   │ │
│  │ │ AKS Subnet              │   │ │
│  │ │ (10.0.1.0/24)           │   │ │
│  │ │ └─ AKS Cluster          │   │ │
│  │ └─────────────────────────┘   │ │
│  │                               │ │
│  │ ┌─────────────────────────┐   │ │
│  │ │ PostgreSQL Flexible     │   │ │
│  │ │ Server (Private)        │   │ │
│  │ └─────────────────────────┘   │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Container Registry (ACR)      │ │
│  │ Standard_B1ms                 │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Key Vault                     │ │
│  │ - DB Connection String        │ │
│  │ - DB Password                 │ │
│  │ - ACR Credentials             │ │
│  └───────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

## Optional: Add VM for Secure Communication

If you need a VM for secure communication between the app and storage:

Add this to `main.tf`:

```hcl
# Add new subnet for VM
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.visitor-counter_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Interface for VM
resource "azurerm_network_interface" "vm_nic" {
  name                = "visitor-counter-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machine
resource "azurerm_windows_virtual_machine" "jumpbox" {
  name                = "visitor-counter-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  vm_size             = "Standard_B2s"

  admin_username = "azureuser"
  admin_password = random_password.vm_admin.result

  network_interface_ids = [azurerm_network_interface.vm_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# Password for VM
resource "random_password" "vm_admin" {
  length           = 20
  override_special = "!@#$%&*()-_=+[]{}<>?"
  special          = true
}

# Store VM password in Key Vault
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = random_password.vm_admin.result
  key_vault_id = azurerm_key_vault.kv.id
}
```

## Troubleshooting

**Error: Resource not found during init**
- Make sure Phase 1 is complete before attempting Phase 2
- Verify storage account was created: `az storage account list --resource-group visitor-counter-rg`

**Error: State lock timeout**
- Check if another terraform operation is running
- Clear locks with: `terraform force-unlock <LOCK_ID>`

**Error: PostgreSQL not accessible**
- PostgreSQL is deployed as private within the VNet
- Only accessible from resources within the VNet (AKS, VM if added)
- Check connection string in Key Vault: `az keyvault secret show --name ConnectionStrings--DefaultConnection --vault-name <kv-name>`

## Next Steps

1. Deploy your application to the AKS cluster using the Kubernetes manifests in `k8s/`
2. Configure PostgreSQL firewall rules if needed for external access
3. Set up CI/CD to build images and push to ACR
4. Configure secrets in the application to read from Key Vault
