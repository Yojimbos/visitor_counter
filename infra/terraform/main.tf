terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

locals {
  suffix              = substr(replace(lower(data.azurerm_client_config.current.subscription_id), "-", ""), 0, 6)
  dns_prefix          = "visitorcounter${local.suffix}"
  backup_storage_name = "vcbackup${local.suffix}"
}

resource "azurerm_resource_group" "rg" {
  name     = "visitor-counter-rg"
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = "visitorcounteracr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}

resource "azurerm_key_vault" "kv" {
  name                        = "visitor-kv-20260410"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true

  sku_name = "standard"
}

resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
  ]

  lifecycle {
    ignore_changes = all
  }
}

resource "random_password" "postgres_admin" {
  length           = 20
  override_special = "!@#$%&*()-_=+[]{}<>?"
  special          = true
}

# Backup strategy:
# 1. Native PostgreSQL backups provide short-retention point-in-time recovery.
# 2. Weekly logical backups are copied to geo-redundant Blob Storage.
# 3. Geo-redundant PostgreSQL backups are codified behind a variable because Azure enables them at server creation time.

resource "azurerm_storage_account" "backup" {
  name                            = local.backup_storage_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = var.backup_storage_replication_type
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
}

resource "azurerm_storage_container" "logical_backups" {
  name                  = "postgres-logical-backups"
  storage_account_name  = azurerm_storage_account.backup.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "backup_retention" {
  storage_account_id = azurerm_storage_account.backup.id

  rule {
    name    = "delete-old-logical-backups"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["postgres/"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.logical_backup_retention_days
      }
    }
  }
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = "visitor-counter-postgres-ne"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.postgres_location
  version                       = "15"
  administrator_login           = "postgresadmin"
  administrator_password        = random_password.postgres_admin.result
  storage_mb                    = 32768
  sku_name                      = "B_Standard_B1ms"
  backup_retention_days         = var.postgres_backup_retention_days
  geo_redundant_backup_enabled  = var.postgres_geo_redundant_backup_enabled
  delegated_subnet_id           = var.postgres_private_network_enabled ? azurerm_subnet.postgres_subnet[0].id : null
  private_dns_zone_id           = var.postgres_private_network_enabled ? azurerm_private_dns_zone.postgres[0].id : null
  public_network_access_enabled = var.postgres_private_network_enabled ? false : true
  zone                          = "1"

  lifecycle {
    ignore_changes = [
      zone # Zone cannot be changed after creation
    ]
  }
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "visitorcounter"
  server_id = azurerm_postgresql_flexible_server.postgres.id
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = random_password.postgres_admin.result
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_virtual_network" "visitor-counter_vnet" {
  name                = "visitor-counter-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_private_dns_zone" "postgres" {
  count               = var.postgres_private_network_enabled ? 1 : 0
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres_vnet" {
  count                 = var.postgres_private_network_enabled ? 1 : 0
  name                  = "visitor-counter-postgres-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = azurerm_virtual_network.visitor-counter_vnet.id
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.aks_cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.visitor-counter_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "postgres_subnet" {
  count                = var.postgres_private_network_enabled ? 1 : 0
  name                 = "visitor-counter-postgres-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.visitor-counter_vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "postgres-flexible-server"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  depends_on = [azurerm_subnet.aks_subnet]

  name                = var.aks_cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = local.dns_prefix
  kubernetes_version  = var.aks_version

  oidc_issuer_enabled = true

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = var.aks_node_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.2.0.0/16"
    dns_service_ip    = "10.2.0.10"
  }
}

resource "azurerm_key_vault_access_policy" "aks_identity" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

  secret_permissions = [
    "Get",
    "List",
  ]

  lifecycle {
    ignore_changes = all
  }
}

# Key Vault secrets
resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = azurerm_postgresql_flexible_server.postgres.fqdn
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "db-user"
  value        = azurerm_postgresql_flexible_server.postgres.administrator_login
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_key_vault_secret" "db_password" {
  name = "ConnectionStrings--DefaultConnection"
  value = format(
    "Host=%s;Database=visitorcounter;Username=%s;Password=%s",
    azurerm_postgresql_flexible_server.postgres.fqdn,
    azurerm_postgresql_flexible_server.postgres.administrator_login,
    random_password.postgres_admin.result,
  )
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_key_vault_secret" "acr_login_server" {
  name         = "acr-login-server"
  value        = azurerm_container_registry.acr.login_server
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_key_vault_secret" "backup_storage_account_name" {
  name         = "backup-storage-account-name"
  value        = azurerm_storage_account.backup.name
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_key_vault_secret" "backup_storage_account_key" {
  name         = "backup-storage-account-key"
  value        = azurerm_storage_account.backup.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_key_vault_secret" "backup_storage_container" {
  name         = "backup-storage-container"
  value        = azurerm_storage_container.logical_backups.name
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = all
  }
}
