output "ip_addresses" {
    value = flatten([for vm in module.vms.ip_addresses: [for addrs in vm: addrs if length(addrs) > 0 && addrs[0] != "127.0.0.1" ]])
}