################################################################################################
# Check ---->  https://registry.terraform.io/providers/CiscoDevNet/fmc/latest For more information
################################################################################################
terraform {
  required_providers {
    fmc = {
      source = "CiscoDevNet/fmc"
    }
  }
}

provider "fmc" {
  fmc_username = var.fmc_username
  fmc_password = var.fmc_password
  fmc_host = var.fmc_host
  fmc_insecure_skip_verify = var.fmc_insecure_skip_verify
}

################################################################################################
# Data blocks
################################################################################################
data "fmc_network_objects" "any-ipv4"{
    name = "any-ipv4"
}

data "fmc_port_objects" "http"{
    name = "HTTP"
}
data "fmc_device_physical_interfaces" "zero_physical_interface" {
    device_id = fmc_devices.device.id
    name = "TenGigabitEthernet0/0"
}
data "fmc_device_physical_interfaces" "one_physical_interface" {
    device_id = fmc_devices.device.id
    name = "TenGigabitEthernet0/1"
}

resource "fmc_smart_license" "license" {
registration_type = "EVALUATION"
}
################################################################################################
# Security Zones
################################################################################################
resource "fmc_security_zone" "inside" {
  name            = "aws-inside-zone"
  interface_mode  = "ROUTED"
}
resource "fmc_security_zone" "outside" {
  name            = "aws-outside-zone"
  interface_mode  = "ROUTED"
}

################################################################################################
# Network & Host Object
################################################################################################

resource "fmc_host_objects" "inside-vm" {
  name        = "aws-inside-vm"
  value       = "10.1.3.20"
}

resource "fmc_host_objects" "outside-gw" {
  name        = "aws-outside-GW"
  value       = "10.1.1.1"
}
################################################################################################
# Access Policy
################################################################################################
resource "fmc_access_policies" "access_policy" {
  name = "aws-access-policy"
  default_action = "BLOCK"
  default_action_send_events_to_fmc = "true"
  default_action_log_end = "true"
}
resource "fmc_access_rules" "access_rule" {
    acp = fmc_access_policies.access_policy.id
    section = "mandatory"
    name = "rule1"
    action = "allow"
    enabled = true
    send_events_to_fmc = true
    log_end = true
    source_zones {
        source_zone {
            id = fmc_security_zone.outside.id
            type = "SecurityZone"
        }

    }
    destination_zones {
        destination_zone {
            id = fmc_security_zone.inside.id
            type = "SecurityZone"
        }
    }
    new_comments = [ "Applied via terraform" ]
}
################################################################################################
# Nat Policy
################################################################################################
resource "fmc_ftd_nat_policies" "nat_policy" {
    name = "aws_nat_policy"
    description = "Nat policy by terraform"
}
resource "fmc_ftd_manualnat_rules" "new_rule" {
    nat_policy = fmc_ftd_nat_policies.nat_policy.id
    nat_type = "static"
    
    source_interface {
        id = fmc_security_zone.outside.id
        type = "SecurityZone"
    }
    destination_interface {
        id = fmc_security_zone.inside.id
        type = "SecurityZone"
    }
    original_source{
        id = data.fmc_network_objects.any-ipv4.id
        type = data.fmc_network_objects.any-ipv4.type
    }

     translated_source{
        id = data.fmc_network_objects.any-ipv4.id
        type = data.fmc_network_objects.any-ipv4.type
    }
    translated_destination {
        id = fmc_host_objects.inside-vm.id
        type =fmc_host_objects.inside-vm.type
    }

    interface_in_original_destination = true
   # interface_in_translated_source = true
   original_destination_port {
    id=data.fmc_port_objects.http.id
    type=data.fmc_port_objects.http.type
   }
    translated_destination_port {
    id=data.fmc_port_objects.http.id
    type=data.fmc_port_objects.http.type
   }
}
################################################################################################
# FTDv Onboarding
################################################################################################
resource "fmc_devices" "device"{
  depends_on = [fmc_ftd_nat_policies.nat_policy, fmc_security_zone.inside, fmc_security_zone.outside]
  name = "aws-ftdv"
  hostname = "10.1.0.10"
  regkey = "cisco"
  #license_caps = [ "MALWARE", "THREAT"]
  access_policy {
      id = fmc_access_policies.access_policy.id
      type = fmc_access_policies.access_policy.type
  }
}
################################################################################################
# Configuring physical interfaces
################################################################################################
resource "fmc_device_physical_interfaces" "physical_interfaces00" {
    enabled = true
    device_id = fmc_devices.device.id
    physical_interface_id= data.fmc_device_physical_interfaces.zero_physical_interface.id
    name =   data.fmc_device_physical_interfaces.zero_physical_interface.name
    security_zone_id= fmc_security_zone.outside.id
    if_name = "outside"
    description = "Applied by terraform"
    mtu =  1500
    mode = "NONE"
    ipv4_static_address = "10.1.1.10"
    ipv4_static_netmask = 24
}
resource "fmc_device_physical_interfaces" "physical_interfaces01" {
    device_id = fmc_devices.device.id
    physical_interface_id= data.fmc_device_physical_interfaces.one_physical_interface.id
    name =   data.fmc_device_physical_interfaces.one_physical_interface.name
    security_zone_id= fmc_security_zone.inside.id
    if_name = "inside"
    description = "Applied by terraform"
    mtu =  1500
    mode = "NONE"
    ipv4_static_address = "10.1.3.10"
    ipv4_static_netmask = 24
}

################################################################################################
# Adding static route
################################################################################################
resource "fmc_staticIPv4_route" "route" {
  depends_on = [fmc_devices.device, fmc_device_physical_interfaces.physical_interfaces00,fmc_device_physical_interfaces.physical_interfaces01]
  metric_value = 25
  device_id  = fmc_devices.device.id
  interface_name = "outside"
  selected_networks {
      id = data.fmc_network_objects.any-ipv4.id
      type = data.fmc_network_objects.any-ipv4.type
      name = data.fmc_network_objects.any-ipv4.name
  }
  gateway {
    object {
      id   = fmc_host_objects.outside-gw.id
      type = fmc_host_objects.outside-gw.type
      name = fmc_host_objects.outside-gw.name
    }
  }
}
################################################################################################
# Attaching NAT Policy to device
################################################################################################
resource "fmc_policy_devices_assignments" "policy_assignment" {
  depends_on = [fmc_staticIPv4_route.route]
  policy {
      id = fmc_ftd_nat_policies.nat_policy.id
      type = fmc_ftd_nat_policies.nat_policy.type
  }
  target_devices {
      id = fmc_devices.device.id
      type = fmc_devices.device.type
  }
}
################################################################################################
# Deploying the changes to the device
################################################################################################
resource "fmc_ftd_deploy" "ftd" {
    depends_on = [fmc_policy_devices_assignments.policy_assignment]
    device = fmc_devices.device.id
    ignore_warning = true
    force_deploy = false
}