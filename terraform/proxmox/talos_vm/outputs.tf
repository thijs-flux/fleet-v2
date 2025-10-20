output "ip_addresses" {
    value = [for vm in proxmox_virtual_environment_vm: vm.talos_vm.ipv4_addresses[0]]
}