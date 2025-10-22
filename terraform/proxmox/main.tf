terraform {
  required_providers {
    talos = {
      source = "siderolabs/talos"
      version = "0.9.0"
    }
    proxmox = {
      source = "bpg/proxmox"
      version = "0.85.0"
    }

  }
}

resource "talos_machine_secrets" "this" {}

module "vms" {
  source = "./talos_vm"
  vm_count = var.control_node_count + var.worker_node_count 
  vm_id = var.vm_id
  pm_addres = var.pm_addres
  pm_token_id = var.pm_token_id
  pm_token_secret = var.pm_token_secret
  pm_username = var.pm_username
  pm_node_name = var.pm_node_name
}

# Designate part of the vms as control, and part as worker. The first control ip is the endpoint.
locals {
  control_ips = slice(module.vms.ip_addresses,0,var.control_node_count)
  worker_ips = slice(module.vms.ip_addresses,var.control_node_count,length(module.vms.ip_addresses))
  endpoint = module.vms.ip_addresses[0]
}
output "control_ips" {
  value = local.control_ips
}
output "worker_ips" {
  value = local.worker_ips
}


# The following parts do the same for both workers and control planes: create a machine config, 
# a client config, and then apply it.
data "talos_machine_configuration" "control" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.endpoint}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode({
      machine = {
        install = {
          # If you update the vm config disk, this might change
          disk = "/dev/sda"
          # We need a specific image for the qemu-guest-agent. When updating talos this should be changed (or be a variable).
          image = "factory.talos.dev/metal-installer/e133d2d977b8029e7cc26def87d5673d727c4451bc796518542db49c2aa4eb1d:v1.11.3"  
        }
      }
      cluster = {
        network = {
          cni = {
            # Otherwise we interfere with cilium
            name = "none"
          }
        }
      }
    })
  ]
}
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${local.endpoint}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
          # We need a specific image for the qemu-guest-agent. When updating talos this should be changed (or be a variable).
          image = "factory.talos.dev/metal-installer/e133d2d977b8029e7cc26def87d5673d727c4451bc796518542db49c2aa4eb1d:v1.11.3"  
        }
      }
      cluster = {
        network = {
          cni = {
            # Otherwise we interfere with cilium
            name = "none"
          }
        }
      }
    })
  ]
}

# this is the same for workers and control nodes, and references all nodes
data "talos_client_configuration" "this" {
  depends_on = [ module.vms ]
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = module.vms.ip_addresses
}

resource "talos_machine_configuration_apply" "control" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control.machine_configuration
  # Cannot be done with for_each as this is not known at plan-time
  count = var.control_node_count
  node                        = local.control_ips[count.index]
}
resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  # Cannot be done with for_each as this is not known at plan-time
  count = var.worker_node_count
  node                        = local.worker_ips[count.index]
}

# Bootstrap the cluster. This starts a very barebones cluster connecting all nodes.
resource "talos_machine_bootstrap" "control" {
  depends_on = [
    talos_machine_configuration_apply.control,
    talos_machine_configuration_apply.worker
  ]
  node                 = local.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
}

# Get kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.control]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.endpoint
}
output "endpoint" {
  value = local.endpoint
}

# Save the kubeconfig file. Move to ~/.kube/config for easy kubectl access.
resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}


# Start the cluster! 
# The certificates etc we get from talos are a different format than the kubernetes provider accepts, so we use the kubeconfig file.
# This can be messy as some providers try to load the kubeconfig before we have saved it.
module "cluster"{
  source = "../cluster"
  client_certificate = null
  client_key = null
  cluster_ca_certificate = null
  config_path = "${path.module}/kubeconfig"
  host = null
  cluster = local_file.kubeconfig
  sops_secret = var.sops_secret
  nfs_server_addr = var.nfs_server_addr
  api_server_addr = local.endpoint
}