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
  suffix     = substr(replace(lower(data.azurerm_client_config.current.subscription_id), "-", ""), 0, 6)
  dns_prefix = "visitorcounter${local.suffix}"
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
  purge_protection_enabled    = false

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
}

resource "random_password" "postgres_admin" {
  length           = 20
  override_special = "!@#$%&*()-_=+[]{}<>?"
  special          = true
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "visitor-counter-postgres-ne"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = "North Europe"
  version                = "15"
  administrator_login    = "postgresadmin"
  administrator_password = random_password.postgres_admin.result
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "visitorcounter"
  server_id = azurerm_postgresql_flexible_server.postgres.id
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = random_password.postgres_admin.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_virtual_network" "visitor-counter_vnet" {
  name                = "visitor-counter-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.aks_cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.visitor-counter_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
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
}

# Key Vault secrets
resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = azurerm_postgresql_flexible_server.postgres.fqdn
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "db-user"
  value        = azurerm_postgresql_flexible_server.postgres.administrator_login
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "ConnectionStrings--DefaultConnection"
  value        = format(
    "Host=%s;Database=visitorcounter;Username=%s;Password=%s",
    azurerm_postgresql_flexible_server.postgres.fqdn,
    azurerm_postgresql_flexible_server.postgres.administrator_login,
    random_password.postgres_admin.result,
  )
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "acr_login_server" {
  name         = "acr-login-server"
  value        = azurerm_container_registry.acr.login_server
  key_vault_id = azurerm_key_vault.kv.id
}

# RBAC for AKS to access ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}