variable "location" {
  description = "Azure region"
  default     = "West Europe"
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