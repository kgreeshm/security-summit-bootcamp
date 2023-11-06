#####################################################################################################################
# Terraform Template to install a Single FTDv in a AZ using BYOL AMI with Mgmt + Diag + Two Interfaces in a New VPC
#####################################################################################################################

#########################################################################################################################
# data
#########################################################################################################################

data "template_file" "startup_file" {
  template = file("ftd_startup_file.txt")
  # vars = {
  #   admin_password       = var.admin_password
  # }
}

# data "aws_vpc" "ftd_vpc" {
#   count = var.existing_vpc ? 1 : 0
#   filter {
#     name   = "tag:Name"
#     values = [var.vpc_name]
#   }
# }

# data "aws_internet_gateway" "default" {
#   count = var.create_igw ? 0 : 1
#   filter {
#     name   = "attachment.vpc-id"
#     values = [data.aws_vpc.ftd_vpc[0].id]
#   }
# }
#########################################################################################################################
# providers
#########################################################################################################################

provider "aws" {
    # access_key = var.aws_access_key
    # secret_key = var.aws_secret_key
    region     =  var.region
}

###########################################################################################################################
#VPC Resources 
###########################################################################################################################
# locals {
#   nw = var.existing_vpc ? data.aws_vpc.ftd_vpc[0].id : aws_vpc.ftd_vpc[0].id
#   igw = var.create_igw ? aws_internet_gateway.int_gw[0].id : data.aws_internet_gateway.default[0].id
# }

resource "aws_vpc" "ftd_vpc" {
  count                =  1
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "mgmt_subnet" {
  vpc_id            = aws_vpc.ftd_vpc[0].id
  cidr_block        = var.mgmt_subnet
  availability_zone = "${var.region}a"
  tags = {
    Name = "Managment subnet"
  }
}

resource "aws_subnet" "diag_subnet" {
  vpc_id            = aws_vpc.ftd_vpc[0].id
  cidr_block        = var.diag_subnet
  availability_zone = "${var.region}a"
  tags = {
    Name = "diag subnet"
  }
}

resource "aws_subnet" "outside_subnet" {
  vpc_id            = aws_vpc.ftd_vpc[0].id
  cidr_block        = var.outside_subnet
  availability_zone = "${var.region}a"
  tags = {
    Name = "outside subnet"
  }
}

resource "aws_subnet" "inside_subnet" {
  vpc_id            = aws_vpc.ftd_vpc[0].id
  cidr_block        = var.inside_subnet
  availability_zone = "${var.region}a"
  tags = {
    Name = "inside subnet"
  }
}


#################################################################################################################################
# Security Group
#################################################################################################################################

resource "aws_security_group" "allow_all" {
  name        = "Allow All"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.ftd_vpc[0].id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Public Allow"
  }
}

##################################################################################################################################
# Network Interfaces, FTD instance, Attaching the SG to interfaces
##################################################################################################################################
resource "aws_network_interface" "ftd01mgmt" {
  description   = "ftd01-mgmt"
  subnet_id     = aws_subnet.mgmt_subnet.id
  private_ips   = [var.ftd01_mgmt_ip]
}

resource "aws_network_interface" "ftd01diag" {
  description = "ftd01-diag"
  subnet_id   = aws_subnet.diag_subnet.id
}

resource "aws_network_interface" "ftd01outside" {
  description = "ftd01-outside"
  subnet_id   = aws_subnet.outside_subnet.id
  private_ips = [var.ftd01_outside_ip]
  source_dest_check = false
}

resource "aws_network_interface" "ftd01inside" {
  description = "ftd01-inside"
  subnet_id   = aws_subnet.inside_subnet.id
  private_ips = [var.ftd01_inside_ip]
  source_dest_check = false
}

resource "aws_network_interface_sg_attachment" "ftd_mgmt_attachment" {
  depends_on           = [aws_network_interface.ftd01mgmt]
  security_group_id    = aws_security_group.allow_all.id
  network_interface_id = aws_network_interface.ftd01mgmt.id
}

resource "aws_network_interface_sg_attachment" "ftd_outside_attachment" {
  depends_on           = [aws_network_interface.ftd01outside]
  security_group_id    = aws_security_group.allow_all.id
  network_interface_id = aws_network_interface.ftd01outside.id
}

resource "aws_network_interface_sg_attachment" "ftd_inside_attachment" {
  depends_on           = [aws_network_interface.ftd01inside]
  security_group_id    = aws_security_group.allow_all.id
  network_interface_id = aws_network_interface.ftd01inside.id
}

##################################################################################################################################
#Internet Gateway and Routing Tables
##################################################################################################################################

//define the internet gateway
resource "aws_internet_gateway" "int_gw" {
  count = 1
  vpc_id = aws_vpc.ftd_vpc[0].id
  tags = {
    Name = "Internet Gateway"
  }
}
//create the route table for outsid & inside
resource "aws_route_table" "ftd_outside_route" {
  vpc_id = aws_vpc.ftd_vpc[0].id

  tags = {
    Name = "outside network Routing table"
  }
}

resource "aws_route_table" "ftd_inside_route" {
  vpc_id = aws_vpc.ftd_vpc[0].id

  tags = {
    Name = "inside network Routing table"
  }
}

//To define the default routes thru IGW
resource "aws_route" "ext_default_route" {
  route_table_id         = aws_route_table.ftd_outside_route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.int_gw[0].id
}

//To define the default route for inside network thur FTDv inside interface 
resource "aws_route" "inside_default_route" {
  depends_on              = [aws_instance.ftdv]
  route_table_id          = aws_route_table.ftd_inside_route.id
  destination_cidr_block  = "0.0.0.0/0"
  network_interface_id    = aws_network_interface.ftd01inside.id

}

resource "aws_route_table_association" "outside_association" {
  subnet_id      = aws_subnet.outside_subnet.id
  route_table_id = aws_route_table.ftd_outside_route.id
}

resource "aws_route_table_association" "mgmt_association" {
  subnet_id      = aws_subnet.mgmt_subnet.id
  route_table_id = aws_route_table.ftd_outside_route.id
}

resource "aws_route_table_association" "inside_association" {
  subnet_id      = aws_subnet.inside_subnet.id
  route_table_id = aws_route_table.ftd_inside_route.id
}
##################################################################################################################################
# AWS External IP address creation and associating it to the mgmt and outside interface. 
##################################################################################################################################
//External ip address creation 

resource "aws_eip" "ftd01mgmt-EIP" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.int_gw,aws_instance.ftdv]
  tags = {
    "Name" = "FTDv-01 Management IP"
  }
}

resource "aws_eip" "ftd01outside-EIP" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.int_gw,aws_instance.ftdv]
  tags = {
    "Name" = "FTDv-01 outside IP"
  }
}

resource "aws_eip_association" "ftd01-mgmt-ip-assocation" {
  network_interface_id = aws_network_interface.ftd01mgmt.id
  allocation_id        = aws_eip.ftd01mgmt-EIP.id
}
resource "aws_eip_association" "ftd01-outside-ip-association" {
    network_interface_id = aws_network_interface.ftd01outside.id
    allocation_id        = aws_eip.ftd01outside-EIP.id
}

##################################################################################################################################
# Create the Cisco NGFW Instances 
##################################################################################################################################
resource "aws_instance" "ftdv" {
    ami                 = "ami-056d05b14edf08aa3"
    instance_type       = var.size 
    key_name            = aws_key_pair.deployer.key_name
    availability_zone   = "${var.region}a"
    
network_interface {
    network_interface_id = aws_network_interface.ftd01mgmt.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.ftd01diag.id
    device_index         = 1
  }
   network_interface {
    network_interface_id = aws_network_interface.ftd01outside.id
    device_index         = 2
  }

    network_interface {
    network_interface_id = aws_network_interface.ftd01inside.id
    device_index         = 3
  }
  
  user_data = data.template_file.startup_file.rendered


  tags = {
    Name = "Cisco FTDv"
  }
}
################################################

resource "tls_private_key" "key_pair" {
algorithm = "RSA"
rsa_bits  = 4096
}

resource "local_file" "private_key" {
content       = tls_private_key.key_pair.private_key_openssh
filename      = "cisco-ftdv-key"
file_permission = 0700
}

resource "aws_key_pair" "deployer" {
  key_name   = "cisco-ftdv-key"
  public_key = tls_private_key.key_pair.public_key_openssh
}
##################################################################################################################################
#Output
##################################################################################################################################
# output "ftd_ip" {
#   value = aws_eip.ftd01mgmt-EIP.public_ip
# }
# output "SSHCommand" {
#   value = "ssh -i cisco-ftdv-key admin@${aws_eip.ftd01mgmt-EIP.public_ip}"
# }