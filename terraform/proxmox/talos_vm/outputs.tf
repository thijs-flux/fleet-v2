output "ip_addresses" {
    value = [for vm in proxmox_virtual_environment_vm.talos_vm: vm.ipv4_addresses]
}