output "client_configuration" {
  value     = module.thebes.client_configuration
  sensitive = true
}

output "kubeconfig" {
  value     = module.thebes.kubeconfig
  sensitive = true
}

output "kubeclientconfig" {
  value     = module.thebes.kubeclientconfig
  sensitive = true
}
