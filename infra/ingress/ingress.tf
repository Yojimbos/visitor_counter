terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    local = {
      source = "hashicorp/local"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Використовуємо data, а не resource
data "azurerm_kubernetes_cluster" "aks" {
  name                = "visitor-counter-aks"
  resource_group_name = "visitor-counter-rg"
}

resource "local_file" "kubeconfig" {
  content  = data.azurerm_kubernetes_cluster.aks.kube_config_raw
  filename = "${path.module}/kubeconfig"
}

provider "helm" {
  kubernetes = {
    config_path = local_file.kubeconfig.filename
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  wait    = true
  timeout = 600

  set = [
    { name = "controller.config.proxy-body-size", value = "512m" },
    { name = "controller.replicaCount", value = "2" },
    { name = "controller.service.externalTrafficPolicy", value = "Local" },
  ]
}