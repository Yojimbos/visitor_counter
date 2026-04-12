resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace_v1.ingress_nginx.metadata[0].name

  wait    = true
  timeout = 600

  set = [
    { name = "controller.config.proxy-body-size", value = "512m" },
    { name = "controller.replicaCount", value = "2" },
    { name = "controller.nodeSelector.kubernetes\\.io/os", value = "linux" },
    { name = "defaultBackend.nodeSelector.kubernetes\\.io/os", value = "linux" },
    { name = "controller.admissionWebhooks.patch.nodeSelector.kubernetes\\.io/os", value = "linux" },
    { name = "controller.service.externalTrafficPolicy", value = "Local" },
  ]
   depends_on = [kubernetes_namespace_v1.ingress_nginx]
}