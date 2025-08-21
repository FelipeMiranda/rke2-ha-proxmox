output "vm_ips" {
  value = {
    for k, v in local.vms : k => v.ip
  }
}

output "vmids" {
  value = {
    for k in local.vm_order : k => local.vmid_map[k]
  }
}

output "vips" {
  value = local.vips
}