variable "location" {
  description = "Azure region"
  default     = "West Europe"
}

variable "postgres_location" {
  description = "Azure region for PostgreSQL Flexible Server. Keep the current value until you are ready for a region-aligned private networking migration."
  type        = string
  default     = "North Europe"
}

variable "resource_group_name" {
  description = "Resource group name"
  default     = "visitor-counter-rg"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster for dev environment"
  type        = string
  default     = "visitor-counter-aks"
}

variable "aks_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.35.0"
}

variable "aks_node_size" {
  description = "VM size for AKS node pool"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "postgres_backup_retention_days" {
  description = "Native Azure PostgreSQL backup retention in days."
  type        = number
  default     = 7
}

variable "postgres_geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups for PostgreSQL Flexible Server. Azure applies this at create time, so turning it on for the current server requires a planned migration or recreation."
  type        = bool
  default     = false
}

variable "postgres_private_network_enabled" {
  description = "Enable private access for PostgreSQL by using a delegated subnet and private DNS. This is prepared in Terraform but should only be enabled during a planned migration because the current PostgreSQL region differs from the AKS VNet region."
  type        = bool
  default     = false
}

variable "backup_storage_replication_type" {
  description = "Replication type for logical backup storage. GRS is the cheapest geo-redundant option."
  type        = string
  default     = "GRS"
}

variable "logical_backup_retention_days" {
  description = "Retention period for weekly logical backups stored in Blob Storage."
  type        = number
  default     = 60
}
