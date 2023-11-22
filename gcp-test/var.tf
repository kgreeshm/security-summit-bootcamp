variable "project_id" {
  type        = string
  description = "The project ID to host the network in"
}

variable "region" {
  type        = string
  description = "The region"
  default     = "us-west1"
}

variable "vm_zones" {
  default = "us-west1-a"
}

variable "prefix" {
  type=string
}

variable "source_ranges" {
  default = ["35.235.240.0/20"]
}

variable "vm_machine_type" {
  type        = string
  description = "machine type for appliance"
  default     = "e2-standard-4"
}

variable "cisco_product_version" {
  type        = string
  description = "cisco product version"
  default     = "cisco-ftdv-7-3-0-69"
}

variable "fmc_ip" {}  
