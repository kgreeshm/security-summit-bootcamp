###############
# Providers
###############
provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_service_account" "sa" {
  account_id   = "bootcamp-${var.prefix}-service-account"
  display_name =  "bootcamp-${var.prefix}-service-account"
}

resource "tls_private_key" "key_pair" {
algorithm = "RSA"
rsa_bits  = 4096
}

resource "local_file" "private_key" {
content       = tls_private_key.key_pair.private_key_openssh
filename      = "bootcamp-${var.prefix}-cisco-ftdv-key"
file_permission = 0700
}

# Create a VPC network
resource "google_compute_network" "ftd-vpc" {
  name                    =  "bootcamp-${var.prefix}-vpc"
  auto_create_subnetworks = false
}

# Create a subnet in the VPC
resource "google_compute_subnetwork" "inside_subnet" {
  name          = "bootcamp-${var.prefix}-inside-subnet"
  ip_cidr_range = "10.0.3.0/24"
  network       = google_compute_network.ftd-vpc.self_link
  region        = var.region
}

resource "google_compute_subnetwork" "outside_subnet" {
  name          = "bootcamp-${var.prefix}-outside-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.ftd-vpc.self_link
  region        = var.region
}

resource "google_compute_subnetwork" "mgmt_subnet" {
  name          = "bootcamp-${var.prefix}-management-subnet"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.ftd-vpc.self_link
  region        = var.region
}

resource "google_compute_subnetwork" "diag_subnet" {
  name          = "bootcamp-${var.prefix}-diagnostic-subnet"
  ip_cidr_range = "10.0.2.0/24"
  network       = google_compute_network.ftd-vpc.self_link
  region        = var.region
}

############################
## Firewall rules ##
############################
resource "google_compute_firewall" "allow-ssh-mgmt" {
  name    = "bootcamp-${var.prefix}-allow-ssh-mgmt"
  network = google_compute_network.ftd-vpc.self_link
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges           = var.source_ranges
  #target_service_accounts = [var.service_account]
}

resource "google_compute_firewall" "allow-https-mgmt" {
  name    = "bootcamp-${var.prefix}-allow-https-mgmt"
  network = google_compute_network.ftd-vpc.self_link
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges           = var.source_ranges
#   target_service_accounts = [var.service_account]
}

resource "google_compute_firewall" "allow-tunnel-mgmt" {
  name    = "bootcamp-${var.prefix}-allow-tunnel-mgmt"
  network = google_compute_network.ftd-vpc.self_link
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8305"]
  }

  source_ranges           = var.source_ranges
#   target_service_accounts = [var.service_account]
}

#############################################
# Instances
#############################################

resource "google_compute_instance" "ftd" {
  provider                  = google
  project                   = var.project_id
  name                      = "bootcamp-${var.prefix}-ftdv"
  zone                      = var.vm_zones
  machine_type              = var.vm_machine_type
  can_ip_forward            = true
  allow_stopping_for_update = true
  
  boot_disk {
    initialize_params {
      image = data.google_compute_image.ftd.self_link
    }
  }

  metadata = {
    ssh-keys       = tls_private_key.key_pair.public_key_openssh
    startup-script = data.template_file.startup_script_ftd.rendered
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.sa.email
    scopes = ["cloud-platform"]
  }

#  network_interface {
#     network = google_compute_network.ftd-vpc.self_link
#     subnetwork = google_compute_subnetwork.inside_subnet.self_link
#   }

  # network_interface {
  #   network = google_compute_network.ftd-vpc.self_link
  #   subnetwork = google_compute_subnetwork.outside_subnet.self_link
  #   access_config {
      
  #   }
  # }

  network_interface {
    network = google_compute_network.ftd-vpc.self_link
    subnetwork = google_compute_subnetwork.mgmt_subnet.self_link
    access_config {
      
    }
  }
  # network_interface {
  #   network = google_compute_network.ftd-vpc.self_link
  #   subnetwork = google_compute_subnetwork.diag_subnet.self_link
  # }
}





