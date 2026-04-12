terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.117.1"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "local_file" "kubeconfig" {
  content  = azurerm_kubernetes_cluster.aks.kube_config_raw
  filename = "${path.module}/kubeconfig"
}

provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}

provider "helm" {
  kubernetes = {
    config_path = local_file.kubeconfig.filename
  }
}