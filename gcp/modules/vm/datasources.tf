###############
# Data Sources
###############
data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}

data "google_compute_image" "ftd" {
  project = "cisco-public"
  name    = var.cisco_product_version
}
# data "google_compute_image" "fmc" {
#   project = "cisco-public"
#   name    = "cisco-fmcv-7-3-0-69"
# }

data "template_file" "startup_script_ftd" {
  template = file("${path.module}/ftd_startup_file.txt")
 vars = {
  #   admin_password = var.admin_password
   fmc_ip = var.fmc_ip
  #   reg_key = "cisco"
  #   fmc_nat_id = ""
 }
}
# data "template_file" "startup_script_fmc" {
#   count    = 1
#   template = file("${path.module}/templates/${var.day_0_config_fmc}")
#   vars = {
#     admin_password = var.admin_password
#     hostname       = "${var.fmc_hostname}%{if var.num_instances > 0}-${count.index + 1}%{endif}"
#   }
# }