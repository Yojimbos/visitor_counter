output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.postgres.name
}