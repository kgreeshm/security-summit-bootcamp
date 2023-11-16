# ###############
# Locals
###############
locals {
  vm_ips_ftd = [for x in google_compute_instance.ftd : x.network_interface.0.access_config.0.nat_ip]
  }

locals {
  ftd_mgmt_ip = [for x in google_compute_instance.ftd : x.network_interface.2.access_config.0.nat_ip]
  }