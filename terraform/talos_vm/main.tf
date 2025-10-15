terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.85.0"
    }
  }
}
# resource "proxmox_virtual_environment_file" "talos" {
#   datastore_id = "local"
#   node_name    = var.node_name
#   content_type = "iso"
#   source_file {
#     path      = "talos-${var.talos_version}.qcow2"
#     file_name = "talos-${var.talos_version}.img"
#   }
# }
provider "proxmox" {
  # Configuration options
  endpoint = var.pm_addres
  username = var.pm_username
  api_token = "${var.pm_username}@pve!${var.pm_token_id}=${var.pm_token_secret}"
  insecure = true
}
resource "proxmox_virtual_environment_vm" "talos_vm" {
  count = var.vm_count
  name        = "${var.name}-${count.index}"
  description = "Managed by Terraform"
  tags        = []
  node_name = var.node_name
  vm_id     = var.vm_id + count.index
  agent {
    enabled = true
  }
  stop_on_destroy = true

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }

  cpu {
    cores        = 2
    type         = "host"  
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "nvme"
    # import_from  = "local:iso/talos-11-2-metal-amd64.qcow2.iso"#proxmox_virtual_environment_file.talos.id
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = 10
    file_format  = "raw"
  }

  cdrom {
    file_id = "local:iso/talos-11-2-metal-amd64.iso"
  }

  initialization {
    # ip_config {
    #   ipv4 {
    #     address = "dhcp"#var.ip_adress
    #     gateway = var.gateway
    #   }
    # }
    user_account {
      username = "talos"
      password = "disabled"
    }
  }

  network_device {
    bridge = "vmbr0"
  }
  network_device {
    bridge = "vlan100"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

#   virtiofs {
#     mapping = "data_share"
#     cache = "always"
#     direct_io = true
#   }
}