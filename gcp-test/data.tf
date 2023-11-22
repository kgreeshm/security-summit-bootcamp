data "google_compute_image" "ftd" {
  project = "cisco-public"
  name    = var.cisco_product_version
}

data "template_file" "startup_script_ftd" {
  template = file("ftd_startup_file.txt")
 vars = {
fmc_ip = var.fmc_ip
 }
}