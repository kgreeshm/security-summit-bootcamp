################################################################################################################################
# Terraform Template to install a Single FTDv in a location using BYOL AMI with Mgmt interface in a New Resource Group
################################################################################################################################

################################################################################################################################
# Provider
################################################################################################################################

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
    subscription_id ="a4f0a716-bddc-4343-adfb-da26bad4ddc0"
}

################################################################################################################################
# Resource Group Creation
################################################################################################################################

# Create a resource group
resource "azurerm_resource_group" "ftdv" {
  name     = "${var.prefix}-RG"
  location = var.location
}

################################################################################################################################
# Data Blocks
################################################################################################################################

data "template_file" "ftd_startup_file" {
  template = file("ftd_startup_file.txt")
  vars = {
    fmc_ip       = var.fmc_ip
    }
}

data "template_file" "apache_install" {
  template = file("apache_install.tpl")
}

data "template_file" "bastion_install" {
  template = file("bastion_install.tpl")
}

################################################################################################################################
# Virtual Network and Subnet Creation
################################################################################################################################

resource "azurerm_virtual_network" "ftdv" {
  name                = "${var.prefix}-virtual-network"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name
  address_space       = [join("", tolist([var.IPAddressPrefix, ".0.0/16"]))]
}

resource "azurerm_subnet" "ftdv-management" {
  name                 = "${var.prefix}-management-subnet"
  resource_group_name  = azurerm_resource_group.ftdv.name
  virtual_network_name = azurerm_virtual_network.ftdv.name
  address_prefixes       = [join("", tolist([var.IPAddressPrefix, ".0.0/24"]))]
}

resource "azurerm_subnet" "ftdv-diagnostic" {
  name                 = "${var.prefix}-diagnostic-subnet"
  resource_group_name  = azurerm_resource_group.ftdv.name
  virtual_network_name = azurerm_virtual_network.ftdv.name
  address_prefixes       = [join("", tolist([var.IPAddressPrefix, ".2.0/24"]))]
}

resource "azurerm_subnet" "ftdv-outside" {
  name                 = "${var.prefix}-outside-subnet"
  resource_group_name  = azurerm_resource_group.ftdv.name
  virtual_network_name = azurerm_virtual_network.ftdv.name
  address_prefixes       = [join("", tolist([var.IPAddressPrefix, ".1.0/24"]))]
}

resource "azurerm_subnet" "ftdv-inside" {
  name                 = "${var.prefix}-inside-subnet"
  resource_group_name  = azurerm_resource_group.ftdv.name
  virtual_network_name = azurerm_virtual_network.ftdv.name
  address_prefixes       = [join("", tolist([var.IPAddressPrefix, ".3.0/24"]))]
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "${var.prefix}bastion-subnet"
  resource_group_name  = azurerm_resource_group.ftdv.name
  virtual_network_name = azurerm_virtual_network.ftdv.name
  address_prefixes     = [join("", tolist([var.IPAddressPrefix, ".4.0/24"]))]
}

################################################################################################################################
# Route Table Creation and Route Table Association
################################################################################################################################

resource "azurerm_route_table" "mgmt-rt" {
  name                = "${var.prefix}-mgmt-RT"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name

}
resource "azurerm_route_table" "diag-rt" {
  name                = "${var.prefix}-diag-RT"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name

}
resource "azurerm_route_table" "outside-rt" {
  name                = "${var.prefix}-outside-RT"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name
}

resource "azurerm_route_table" "inside-rt" {
  name                = "${var.prefix}-Inside-RT"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name
}

resource "azurerm_route_table" "bastion_rt" {
  name                = "${var.prefix}-bastion-RT"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name

}

# resource "azurerm_route" "local-route" {
#   name                = "local-route"
#   resource_group_name = azurerm_resource_group.ftdv.name
#   route_table_name    = azurerm_route_table.inside-rt.name
#   address_prefix      = "10.20.0.0/16"
#   next_hop_type       = "VnetLocal"
# }

resource "azurerm_route" "ext-route" {
  name                = "ext-route"
  resource_group_name = azurerm_resource_group.ftdv.name
  route_table_name    = azurerm_route_table.outside-rt.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "inside-route" {
  name                = "inside-route"
  resource_group_name = azurerm_resource_group.ftdv.name
  route_table_name    = azurerm_route_table.inside-rt.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "VirtualAppliance"
 next_hop_in_ip_address = azurerm_network_interface.ftdv-interface-inside.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "mgmt-rta" {
  subnet_id                 = azurerm_subnet.ftdv-management.id
  route_table_id            = azurerm_route_table.outside-rt.id
}
resource "azurerm_subnet_route_table_association" "diag-rta" {
  subnet_id                 = azurerm_subnet.ftdv-diagnostic.id
  route_table_id            = azurerm_route_table.outside-rt.id
}
resource "azurerm_subnet_route_table_association" "outside-rta" {
  subnet_id                 = azurerm_subnet.ftdv-outside.id
  route_table_id            = azurerm_route_table.outside-rt.id
}
resource "azurerm_subnet_route_table_association" "inside-rta" {
  subnet_id                 = azurerm_subnet.ftdv-inside.id
  route_table_id            = azurerm_route_table.inside-rt.id
}

resource "azurerm_subnet_route_table_association" "bastion_rta" {
  subnet_id      = azurerm_subnet.bastion_subnet.id
  route_table_id = azurerm_route_table.outside-rt.id
}

################################################################################################################################
# Network Security Group Creation
################################################################################################################################

resource "azurerm_network_security_group" "allow-all" {
    name                = "${var.prefix}-allow-all-sg"
    location            = var.location
    resource_group_name = azurerm_resource_group.ftdv.name

    security_rule {
        name                       = "TCP-Allow-All"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = var.source-address
        destination_address_prefix = "*"
    }
    security_rule {
        name                       = "Outbound-Allow-All"
        priority                   = 1002
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = var.source-address
        destination_address_prefix = "*"
    }

}

################################################################################################################################
# Network Interface Creation, Public IP Creation and Network Security Group Association
################################################################################################################################

resource "azurerm_network_interface" "ftdv-interface-management" {
  name                      = "${var.prefix}-mgmt-Nic0"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.ftdv.name

  ip_configuration {
    name                          = "Nic0"
    subnet_id                     = azurerm_subnet.ftdv-management.id
    private_ip_address_allocation = "Static"
     private_ip_address="10.20.0.20"
    public_ip_address_id          = azurerm_public_ip.ftdv-mgmt-interface.id
  }
  enable_ip_forwarding=true
}
resource "azurerm_network_interface" "ftdv-interface-diagnostic" {
  name                      = "${var.prefix}-diag-Nic1"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.ftdv.name
  depends_on                = [azurerm_network_interface.ftdv-interface-management]
  ip_configuration {
    name                          = "Nic1"
    subnet_id                     = azurerm_subnet.ftdv-diagnostic.id
    private_ip_address_allocation = "Static"
    private_ip_address="10.20.2.10"
  }
  enable_ip_forwarding=true
}
resource "azurerm_network_interface" "ftdv-interface-outside" {
  name                      = "${var.prefix}-outside-Nic2"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.ftdv.name
  depends_on                = [azurerm_network_interface.ftdv-interface-diagnostic]
  ip_configuration {
    name                          = "Nic2"
    subnet_id                     = azurerm_subnet.ftdv-outside.id
    private_ip_address_allocation = "Static"
      private_ip_address="10.20.1.10"
    public_ip_address_id          = azurerm_public_ip.ftdv-outside-interface.id
  }
  enable_ip_forwarding=true
}
resource "azurerm_network_interface" "ftdv-interface-inside" {
  name                      = "${var.prefix}-inside-Nic3"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.ftdv.name
  depends_on                = [azurerm_network_interface.ftdv-interface-outside]
  ip_configuration {
    name                          = "Nic3"
    subnet_id                     = azurerm_subnet.ftdv-inside.id
    private_ip_address_allocation = "Static"
    private_ip_address="10.20.3.10"
  }
  enable_ip_forwarding=true
}

resource "azurerm_network_interface" "application-nic" {
  name                = "${var.prefix}-inside-vm-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name

  ip_configuration {
    name                          = "${var.prefix}-inside-vm-nic"
    subnet_id                     = azurerm_subnet.ftdv-inside.id
    private_ip_address_allocation = "Static"
     private_ip_address="10.20.3.20"
  }
  enable_ip_forwarding=true
}

resource "azurerm_network_interface" "bastion-nic" {
  name                = "${var.prefix}-bastion-vm-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name

  ip_configuration {
    name                          = "${var.prefix}-bastion-vm-nic"
    subnet_id                     = azurerm_subnet.bastion_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.20.4.10"
    public_ip_address_id          = azurerm_public_ip.bastion-publicIP.id
  }
  enable_ip_forwarding=true
}


resource "azurerm_public_ip" "ftdv-mgmt-interface" {
    name                         = "${var.prefix}-management-public-ip"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.ftdv.name
    allocation_method            = "Dynamic"
}
resource "azurerm_public_ip" "ftdv-outside-interface" {
    name                         = "${var.prefix}-outside-public-ip"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.ftdv.name
    allocation_method            = "Dynamic"
}

resource "azurerm_public_ip" "bastion-publicIP" {
  name                = "bastion-publicIP"
  location            = var.location
  resource_group_name = azurerm_resource_group.ftdv.name
  allocation_method   = "Dynamic"
}


resource "azurerm_network_interface_security_group_association" "FTDv_NIC0_NSG" {
  network_interface_id      = azurerm_network_interface.ftdv-interface-management.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}
resource "azurerm_network_interface_security_group_association" "FTDv_NIC1_NSG" {
  network_interface_id      = azurerm_network_interface.ftdv-interface-diagnostic.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}
resource "azurerm_network_interface_security_group_association" "FTDv_NIC2_NSG" {
  network_interface_id      = azurerm_network_interface.ftdv-interface-outside.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}
resource "azurerm_network_interface_security_group_association" "FTDv_NIC3_NSG" {
  network_interface_id      = azurerm_network_interface.ftdv-interface-inside.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}

resource "azurerm_network_interface_security_group_association" "application-nic-association" {
  network_interface_id      = azurerm_network_interface.application-nic.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}

resource "azurerm_network_interface_security_group_association" "bastion-nic-association" {
  network_interface_id      = azurerm_network_interface.bastion-nic.id
  network_security_group_id = azurerm_network_security_group.allow-all.id
}
################################################################################################################################
# FTDv Instance Creation
################################################################################################################################

resource "azurerm_virtual_machine" "ftdv-instance" {
  name                  = "${var.prefix}-ftdv"
  location              = var.location
  resource_group_name   = azurerm_resource_group.ftdv.name
  
  depends_on = [
    azurerm_network_interface.ftdv-interface-management,
    azurerm_network_interface.ftdv-interface-diagnostic,
    azurerm_network_interface.ftdv-interface-outside,
    azurerm_network_interface.ftdv-interface-inside
  ]
  
  primary_network_interface_id = azurerm_network_interface.ftdv-interface-management.id
  network_interface_ids = [azurerm_network_interface.ftdv-interface-management.id,
                                                        azurerm_network_interface.ftdv-interface-diagnostic.id,
                                                        azurerm_network_interface.ftdv-interface-outside.id,
                                                        azurerm_network_interface.ftdv-interface-inside.id]
  vm_size               = var.VMSize


  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  plan {
    name = "ftdv-azure-byol"
    publisher = "cisco"
    product = "cisco-ftdv"
  }

  storage_image_reference {
    publisher = "cisco"
    offer     = "cisco-ftdv"
    sku       = "ftdv-azure-byol"
    version   = var.Version
  }
  storage_os_disk {
    name              = "myosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    admin_username = var.username
    admin_password = var.password
    computer_name  = var.instancename
    custom_data = data.template_file.ftd_startup_file.rendered

  }
  os_profile_linux_config {
    disable_password_authentication = false

  }
}

################################################################################################################################
# Test Machines
################################################################################################################################

resource "azurerm_linux_virtual_machine" "application-vm" {
  depends_on = [ azurerm_linux_virtual_machine.bastion-vm ]
  name                = "${var.prefix}-inside-vm"
  resource_group_name = azurerm_resource_group.ftdv.name
  location            = var.location
  size                = "Standard_B1s"
  admin_username      = "ubuntu"
  network_interface_ids = [azurerm_network_interface.application-nic.id]
disable_password_authentication=false
admin_password ="Cisco@123"

  # admin_ssh_key {
  #   username   = "ubuntu"
  #   public_key = file("~/.ssh/id_rsa.pub")
  # }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  custom_data = base64encode(data.template_file.apache_install.rendered) 
}


resource "azurerm_linux_virtual_machine" "bastion-vm" {
  name                = "${var.prefix}-bastion-vm"
  resource_group_name = azurerm_resource_group.ftdv.name
  location            = var.location
  size                = "Standard_B1s"
   disable_password_authentication = false
  admin_username      = "ubuntu"
  admin_password ="Cisco@123"
  network_interface_ids = [azurerm_network_interface.bastion-nic.id]

  # admin_ssh_key {
  #   username   = "cisco"
  #   public_key = file("~/.ssh/id_rsa.pub")
  # }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version = "latest"
  }
  custom_data = base64encode(data.template_file.bastion_install.rendered) 
}

################################################################################################################################
# Output
################################################################################################################################
data "azurerm_public_ip" "example" {
  name                = azurerm_public_ip.ftdv-outside-interface.name
  resource_group_name = azurerm_resource_group.ftdv.name
}
output "Command-to-test" {
  #value = "http://${azurerm_public_ip.ftdv-outside-interface.ip_address}"
  value="http://${data.azurerm_public_ip.example.ip_address}"
}

