output "ip_addresses" {
    value = {for vm in proxmox_virtual_environment_vm.talos_vm: "node-${vm.ipv4_addresses}" => vm.ipv4_addresses[0]}
}