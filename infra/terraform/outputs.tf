output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_id" {
  value = azurerm_container_registry.acr.id
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.postgres.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "postgres_admin_password" {
  value     = random_password.postgres_admin.result
  sensitive = true
}