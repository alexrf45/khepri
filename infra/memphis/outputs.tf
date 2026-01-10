output "client_configuration" {
  value     = module.memphis.client_configuration
  sensitive = true
}

output "kubeconfig" {
  value     = module.memphis.kubeconfig
  sensitive = true
}

output "kubeclientconfig" {
  value     = module.memphis.kubeclientconfig
  sensitive = true
}
