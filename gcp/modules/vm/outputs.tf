output "external_ips_ftd" {
  value       = local.vm_ips_ftd
  description = "external ips for VPC networks-FTD"
}

output "ftd-mgmt-ip"{
  value=local.ftd_mgmt_ip
}

output "instance_ids" {
  value       = google_compute_instance.ftd[*].id
  description = "a list of instance ids"
}