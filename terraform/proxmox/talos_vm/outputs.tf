output "ip_addresses" {
    value = flatten([for vm in proxmox_virtual_environment_vm.talos_vm: [for addrs in vm.ipv4_addresses: addrs if length(addrs) > 0 && startswith(addrs[0],"10.51") ]])
}