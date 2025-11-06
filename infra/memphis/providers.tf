provider "aws" {

}

provider "talos" {
}

provider "proxmox" {
  endpoint = "https://${var.pve_hosts.endpoint}:8006"
  username = "root@pam"
  password = var.pve_hosts.password
  insecure = true
  ssh {
    agent = false
  }
}


