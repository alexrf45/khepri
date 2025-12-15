output "client_configuration" {
  value     = module.abydos.client_configuration
  sensitive = true
}

output "kubeconfig" {
  value     = module.abydos.kubeconfig
  sensitive = true
}

output "kubeclientconfig" {
  value     = module.abydos.kubeclientconfig
  sensitive = true
}
