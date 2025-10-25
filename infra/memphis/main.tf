module "memphis" {
  source = "./talos-pve-v2.0.0"
  #source        = "git@github.com:alexrf45/lab.git//talos-pve-v2.0.0"
  environment   = var.environment
  cluster       = var.cluster
  pve_hosts     = var.pve_hosts
  nodes         = var.nodes
  cilium_config = var.cilium_config
  dns_servers   = var.dns_servers
}
