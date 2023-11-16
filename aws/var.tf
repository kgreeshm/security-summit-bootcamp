#####################################################################################################################
# Variables 
#####################################################################################################################

variable "aws_access_key" {
    default = ""
}
variable "aws_secret_key" {
    default = ""
}

variable "prefix" {
    default = "Bootcamp"
}
variable "admin_password" {
    default = "Cisco@123"
}
variable "region" {
        default = "us-east-1"
}

variable "FTD_version" {
    default = "ftdv-7.3.0"
} 



variable "vpc_name" {
    default = "Bootcamp-VPC"
}

//Including the Avilability Zone
variable "aws_az" {
    default = "us-east-1a"
}

//defining the VPC CIDR
variable "vpc_cidr" {
    default = "10.1.0.0/16"
}

// defining the subnets variables with the default value for Three Tier Architecure. 

variable "mgmt_subnet" {
    default = "10.1.0.0/24"
}

variable "ftd01_mgmt_ip" {
    default = "10.1.0.10"
}

variable "ftd01_outside_ip" {
    default = "10.1.1.10"
}

variable "ftd01_inside_ip" {
    default = "10.1.3.10"
}
        
variable "ftd01_diag_ip" {
    default = "10.1.2.10"
}        

variable "fmc_mgmt_ip" {
    default = "10.1.0.20"
} 

variable "inside_nic_ip" {
    default = "10.1.3.20"
} 

variable "bastion_ip" {
    default = "10.1.4.10"
} 

variable "diag_subnet" {
    default = "10.1.2.0/24"
}

variable "outside_subnet" {
    default = "10.1.1.0/24"
}

variable "inside_subnet" {
    default = "10.1.3.0/24"
}

variable "bastion_subnet" {
    default = "10.1.4.0/24"
}

variable "size" {
  default = "c5.4xlarge"
}
