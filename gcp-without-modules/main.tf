#############################################
# Enable required services on the project
#############################################
resource "google_project_service" "service" {
  for_each = toset(var.project_services)
  project  = var.project_id

  service            = each.key
  disable_on_destroy = false
}

##################################################################################################################################
# Service account
##################################################################################################################################

resource "google_service_account" "sa" {
  account_id   = "terraform-service-account"
  display_name = "terraform-service-account"
}

/******************************************
	VPC configuration
 *****************************************/
resource "google_compute_network" "network" {
  name                                      = "VPC"
  routing_mode                              = "REGIONAL"
 # project                                   = var.project_id 
}

resource "google_compute_subnetwork" "mgmt-subnet" {
  name          = "management-subnet"
  ip_cidr_range = "10.10.0.0/24"
  network       = google_compute_network.network.id
}

resource "google_compute_subnetwork" "diag-subnet" {
  name          = "diag-subnet"
  ip_cidr_range = "10.10.0.0/24"
  network       = google_compute_network.network.id
}

resource "google_compute_subnetwork" "outside-subnet" {
  name          = "outside-subnet"
  ip_cidr_range = "10.10.0.0/24"
  network       = google_compute_network.network.id
}

resource "google_compute_subnetwork" "inside-subnet" {
  name          = "inside-subnet"
  ip_cidr_range = "10.10.0.0/24"
  network       = google_compute_network.network.id
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

############################
## management VPC ##
############################
resource "google_compute_firewall" "allow-ssh-mgmt" {
  name    = "allow-ssh-mgmt-${random_string.suffix.result}"
  network = module.vpc-module[var.mgmt_network].network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges           = ["152.58.196.247/32"]
  target_service_accounts = [var.service_account]
}

resource "google_compute_firewall" "allow-https-mgmt" {
  name    = "allow-https-mgmt-${random_string.suffix.result}"
  network = module.vpc-module[var.mgmt_network].network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges           = ["152.58.196.247/32"]
  target_service_accounts = [var.service_account]
}

resource "google_compute_firewall" "allow-tunnel-mgmt" {
  name    = "allow-tunnel-mgmt-${random_string.suffix.result}"
  network = module.vpc-module[var.mgmt_network].network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8305"]
  }

  source_ranges           = ["152.58.196.247/32"]
  target_service_accounts = [var.service_account]
}


############################
## outside VPC ##
############################

resource "google_compute_firewall" "allow-ssh-outside" {
  name    = "allow-tcp-outside-${random_string.suffix.result}"
  network = module.vpc-module[var.outside_network].network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges           = ["152.58.196.247/32"]
  target_service_accounts = [var.service_account]
}

resource "google_compute_firewall" "allow-http-outside" {
  name    = "allow-http-outside-${random_string.suffix.result}"
  network = module.vpc-module[var.outside_network].network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges           = ["152.58.196.247/32"]
  target_service_accounts = [var.service_account]
}

############################
## inside VPC ##
############################

resource "google_compute_firewall" "allow-ssh-inside" {
  name    = "allow-tcp-inside-${random_string.suffix.result}"
  network = module.vpc-module[var.inside_network].network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges           = ["152.58.196.247/32"]
  target_service_accounts = [var.service_account]
}

resource "google_compute_firewall" "allow-http-inside" {
  name    = "allow-http-inside-${random_string.suffix.result}"
  network = module.vpc-module[var.inside_network].network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges           = ["152.58.196.247/32"]
  target_service_accounts = [var.service_account]
}