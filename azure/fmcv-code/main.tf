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
    name = "GigabitEthernet0/0"
}
data "fmc_device_physical_interfaces" "one_physical_interface" {
    device_id = fmc_devices.device.id
    name = "GigabitEthernet0/1"
}


resource "fmc_smart_license" "license" {
registration_type = "EVALUATION"
}
################################################################################################
# Security Zones
################################################################################################
resource "fmc_security_zone" "inside" {
  name            = "azure-inside-zone3"
  interface_mode  = "ROUTED"
}
resource "fmc_security_zone" "outside" {
  name            = "azure-outside-zone3"
  interface_mode  = "ROUTED"
}

################################################################################################
# Network & Host Object
################################################################################################


resource "fmc_host_objects" "inside-vm" {
  name        = "azure-inside-vm3"
  value       = "10.20.3.20" 
}

resource "fmc_host_objects" "outside-gw" {
  name        = "azure-outside-gw3"
  value       = "10.20.1.1"
}
################################################################################################
# Access Policy
################################################################################################
resource "fmc_access_policies" "access_policy" {
  name = "azure-access-policy3"
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
    # source_networks {
    #     source_network {
    #         id = data.fmc_network_objects.any-ipv4.id
    #         type =  data.fmc_network_objects.source.type
    #     }
    # }
    # destination_networks {
    #     destination_network {
    #         id = fmc_host_objects.inside-vm
    #         type =  data.fmc_network_objects.dest.type
    #     }
    # }
    new_comments = [ "Applied via terraform" ]
}
################################################################################################
# Nat Policy
################################################################################################
resource "fmc_ftd_nat_policies" "nat_policy" {
    name = "azure-nat_policy3"
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
  name = "azure-ftdv3"
  hostname ="10.20.0.20"
  regkey = "cisco"
  #license_caps = [ "MALWARE", "THREAT"]
  # nat_id = "cisco"
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
    ipv4_static_address ="10.20.1.10"
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
    ipv4_static_address ="10.20.3.10"
    ipv4_static_netmask = 24
}
# resource "fmc_device_physical_interfaces" "physical_interfaces02" {
#     device_id = fmc_devices.device.id
#     physical_interface_id= data.fmc_device_physical_interfaces.two_physical_interface.id
#     name =   data.fmc_device_physical_interfaces.two_physical_interface.name
#     security_zone_id= fmc_security_zone.inside2.id
#     if_name = "in20"
#     description = "Applied by terraform"
#     mtu =  1500
#     mode = "NONE"
#     ipv4_static_address = "198.19.20.1"
#     ipv4_static_netmask = 24
# }
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