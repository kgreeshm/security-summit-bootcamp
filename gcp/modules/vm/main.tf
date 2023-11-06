#############################################
# Instances
#############################################

resource "google_compute_instance" "ftd" {
  provider                  = google
  count                     = var.num_instances
  project                   = var.project_id
  name                      = "${var.ftd_hostname}-${count.index + 1}"
  zone                      = var.vm_zones[count.index]
  machine_type              = var.vm_machine_type
  can_ip_forward            = true
  allow_stopping_for_update = true
  tags                      = try(var.vm_instance_tags, [])
  labels                    = try(var.vm_instance_labels, {})

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ftd.self_link
    }
  }

  metadata = {
    ssh-keys       = var.keypair
    startup-script = data.template_file.startup_script_ftd.rendered
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = var.service_account
    scopes = ["cloud-platform"]
  }

  dynamic "network_interface" {
    for_each = var.networks_list
    content {
      subnetwork = network_interface.value.subnet_self_link
      network_ip = network_interface.value.appliance_ip[count.index]
      dynamic "access_config" { # Needed for getting public IP.
        for_each = network_interface.value.external_ip ? ["external_ip"] : []
        content {
          nat_ip = null
          # nat_ip       = access_config.value.address
          network_tier = "PREMIUM"
        }
      }
    }
  }
}

