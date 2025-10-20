variable "control_node_count" {
    type = "int"
  
}
variable "worker_node_count" {
    type = "int"
  
}
variable "sops_secret" {
  
}

variable "cluster_name" {
  default = "cluster"
}

# Proxmox variables
variable "vm_name" {
    default = "zts-k8s-thijs" 
}
variable "pm_node_name" {
    
}
variable "vm_id" {
  
}
variable "talos_version" {
    default = "11.2"
}
variable "pm_addres" {
  
}
variable "pm_username" {
  
}
variable "pm_token_id" {
  
}
variable "pm_token_secret" {
  
}