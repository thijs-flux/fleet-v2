output "ip_addresses" {
    value = flatten([for vm in proxmox_virtual_environment_vm.talos_vm: [for addrs in vm: addrs if length(addrs) > 0 && addrs[0] != "127.0.0.1" ]])
}