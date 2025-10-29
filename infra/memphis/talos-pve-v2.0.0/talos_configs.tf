locals {
  # Common cluster network configuration for all nodes
  cluster_network_config = {
    network = {
      cni = {
        name = "none"
      }
      podSubnets = [
        "10.42.0.0/16"
      ]
      serviceSubnets = [
        "10.43.0.0/16"
      ]
    }
  }

  # Tailscale extension configuration
  tailscale_config = {
    apiVersion = "v1alpha1"
    kind       = "ExtensionServiceConfig"
    name       = "tailscale"
    environment = [
      "TS_AUTHKEY=${var.cluster.tailscale_auth}"
    ]
  }

  # Control plane machine configuration
  controlplane_machine_config = {
    machine = {
      sysctls = {
        "vm.nr_hugepages" = "2048"
      }
      kernel = {
        modules = [
          { name = "nvme_tcp" },
          { name = "vfio_pci" }
        ]
      }
      files = [
        {
          path = "/etc/cri/conf.d/20-customization.part"
          op   = "create"
          content = <<-EOT
            [plugins."io.containerd.cri.v1.images"]
              discard_unpacked_layers = false
            [plugins."io.containerd.cri.v1.runtime"]
              device_ownership_from_security_context = true
          EOT
        }
      ]
      time = {
        servers = ["time.cloudflare.com"]
      }
      kubelet = {
        extraArgs = {
          "rotate-server-certificates" = "true"
        }
        clusterDNS = ["10.43.0.10"]
        extraMounts = [
          {
            destination = var.cluster.storage_disk
            type        = "bind"
            source      = var.cluster.storage_disk
            options = [
              "rbind",
              "rshared",
              "rw"
            ]
          }
        ]
      }
      disks = [
        {
          device = "/dev/vdb"
          partitions = [
            {
              mountpoint = var.cluster.storage_disk
            }
          ]
        }
      ]
      install = {
        disk  = var.cluster.install_disk
        image = talos_image_factory_schematic.controlplane.id
        extraKernelArgs = [
          "console=ttyS1",
          "panic=10",
          "cpufreq.default_governor=performance",
          "intel_idle.max_cstate=0",
          "disable_ipv6=1"
        ]
      }
    }
  }

  # Worker node machine configuration
  worker_machine_config = {
    machine = {
      sysctls = {
        "vm.nr_hugepages" = "2048"
      }
      kernel = {
        modules = [
          { name = "nvme_tcp" },
          { name = "vfio_pci" }
        ]
      }
      files = [
        {
          path = "/etc/cri/conf.d/20-customization.part"
          op   = "create"
          content = <<-EOT
            [plugins."io.containerd.cri.v1.images"]
              discard_unpacked_layers = false
            [plugins."io.containerd.cri.v1.runtime"]
              device_ownership_from_security_context = true
          EOT
        }
      ]
      time = {
        servers = ["time.cloudflare.com"]
      }
      kubelet = {
        extraArgs = {
          "rotate-server-certificates" = "true"
        }
        clusterDNS = ["10.43.0.10"]
        extraMounts = [
          {
            destination = var.cluster.storage_disk_1
            type        = "bind"
            source      = var.cluster.storage_disk_1
            options = [
              "rbind",
              "rshared",
              "rw"
            ]
          },
          {
            destination = var.cluster.storage_disk_2
            type        = "bind"
            source      = var.cluster.storage_disk_2
            options = [
              "rbind",
              "rshared",
              "rw"
            ]
          }
        ]
      }
      disks = [
        {
          device = "/dev/vdb"
          partitions = [
            {
              mountpoint = var.cluster.storage_disk_1
            }
          ]
        },
        {
          device = "/dev/vdc"
          partitions = [
            {
              mountpoint = var.cluster.storage_disk_2
            }
          ]
        }
      ]
      install = {
        disk  = var.cluster.install_disk
        image = talos_image_factory_schematic.worker.id
        extraKernelArgs = [
          "console=ttyS1",
          "panic=10",
          "cpufreq.default_governor=performance",
          "intel_idle.max_cstate=0",
          "disable_ipv6=1"
        ]
      }
    }
  }

  # Control plane cluster configuration
  controlplane_cluster_config = {
    cluster = merge(
      local.cluster_network_config,
      {
        apiServer = {
          auditPolicy = {
            apiVersion = "audit.k8s.io/v1"
            kind       = "Policy"
            rules = [
              { level = "Metadata" }
            ]
          }
          admissionControl = [
            {
              name = "PodSecurity"
              configuration = {
                apiVersion = "pod-security.admission.config.k8s.io/v1beta1"
                kind       = "PodSecurityConfiguration"
                exemptions = {
                  namespaces = [
                    "networking",
                    "storage"
                  ]
                }
              }
            }
          ]
        }
        proxy = {
          disabled = true
        }
        extraManifests = [
          "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
          "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml",
          "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml"
        ]
        inlineManifests = [
          {
            name = "namespace-flux"
            contents = yamlencode({
              apiVersion = "v1"
              kind       = "Namespace"
              metadata = {
                name = "flux-system"
              }
            })
          },
          {
            name = "namespace-networking"
            contents = yamlencode({
              apiVersion = "v1"
              kind       = "Namespace"
              metadata = {
                name = "networking"
                labels = {
                  "pod-security.kubernetes.io/enforce" = "privileged"
                  "app"                                 = "networking"
                }
              }
            })
          },
          {
            name = "namespace-storage"
            contents = yamlencode({
              apiVersion = "v1"
              kind       = "Namespace"
              metadata = {
                name = "storage"
                labels = {
                  "pod-security.kubernetes.io/enforce" = "privileged"
                  "app"                                 = "storage"
                }
              }
            })
          }
        ]
      }
    )
  }

  # Generate per-node control plane configs
  controlplane_configs = {
    for k, v in var.nodes : k => merge(
      local.controlplane_machine_config,
      {
        machine = merge(
          local.controlplane_machine_config.machine,
          {
            network = {
              interfaces = [
                {
                  interface = "eth0"
                  dhcp      = false
                  vip = {
                    ip = var.cluster.vip_ip
                  }
                }
              ]
              hostname = format("${var.environment}-${var.cluster.name}-cp-${random_id.example[k].hex}")
              nameservers = [
                var.dns_servers.primary,
                var.dns_servers.secondary
              ]
            }
          }
        )
      },
      local.controlplane_cluster_config,
      {
        cluster = merge(
          local.controlplane_cluster_config.cluster,
          {
            allowSchedulingOnControlPlanes = v.allow_scheduling
            inlineManifests = concat(
              local.controlplane_cluster_config.cluster.inlineManifests,
              [
                {
                  name = "cilium"
                  contents = join("---\n", [
                    data.helm_template.this.manifest,
                    "# Source cilium.tf\n${local.cilium_lb_manifest}",
                  ])
                }
              ]
            )
          }
        )
      }
    ) if v.machine_type == "controlplane"
  }

  # Generate per-node worker configs
  worker_configs = {
    for k, v in var.nodes : k => merge(
      local.worker_machine_config,
      {
        machine = merge(
          local.worker_machine_config.machine,
          {
            network = {
              hostname = format("${var.environment}-${var.cluster.name}-node-${random_id.example[k].hex}")
              nameservers = [
                var.dns_servers.primary,
                var.dns_servers.secondary
              ]
              interfaces = [
                {
                  interface = "eth0"
                  dhcp      = false
                }
              ]
            }
          }
        )
      },
      # Add cluster network config to workers
      { cluster = local.cluster_network_config }
    ) if v.machine_type == "worker"
  }
}
