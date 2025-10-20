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

locals {
  control_ips = slice(module.vms.ip_addresses,0,var.control_node_count)
  worker_ips = slice(module.vms.ip_addresses,var.control_node_count+1,length(module.vms.ip_addresses))
  endpoint = local.control_ips[0]
}



data "talos_machine_configuration" "control" {
  depends_on = [ module.vms ]
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.endpoint}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
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
        }
      }
    })
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [ module.vms.ip_addresses]
}

resource "talos_machine_configuration_apply" "control" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control.machine_configuration
  for_each = local.control_ips
  node                        = each.value
}
resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  for_each = local.worker_ips
  node                        = each.value
}

resource "talos_machine_bootstrap" "control" {
  depends_on = [
    talos_machine_configuration_apply.control
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
resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}

# provider "kubernetes" {
#   host = var.ip_addres
#   config_path = "${path.module}/kubeconfig"
# }
module "cluster"{
  source = "../cluster"
  client_certificate = null
  client_key = null
  cluster_ca_certificate = null
  config_path = "${path.module}/kubeconfig"
  host = null#"https://${var.ip_addres}"
  cluster = talos_cluster_kubeconfig.this
  sops_secret = var.sops_secret
}