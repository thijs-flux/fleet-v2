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

variable "control_addres" {
  default="134.221.51.161"
}
variable "worker_addres" {
  default="134.221.51.162"
}
variable "gateway" {
  default = "134.221.51.1"
}
variable "cluster_name" {
  default = "cluster"
}


data "talos_machine_configuration" "control" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.control_addres}:6443"
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
  cluster_endpoint = "https://${var.worker_addres}:6443"
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
  nodes                = [var.control_addres, var.worker_addres]
}

resource "talos_machine_configuration_apply" "control" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control.machine_configuration
  node                        = var.control_addres
}
resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.worker_addres
}

resource "talos_machine_bootstrap" "control" {
  depends_on = [
    talos_machine_configuration_apply.control
  ]
  node                 = var.control_addres
  client_configuration = talos_machine_secrets.this.client_configuration
}

# Get kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.control]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_addres
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