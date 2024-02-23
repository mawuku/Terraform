terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#Configure the AWS provider
provider "aws" {
  profile = "infra-admin-377331541806"
  region  = "us-east-1"
}

# Define variabes for ingress & egress SG rules.
variable "ingressrules"  {
  type = list(number)
  default = [22,80,443]
}

variable "egressrules"  {
  type = list(number)
  default = [22,80,443]
}

# Define variables for VPN IPs or User plublic IP
# [TODO] get this variable from from user. For now user needs to edit terraform file to updatethe value. 
# [TODO] use a list to get multiple IPs
# not providing a defult to avoid using 0.0.0.0/0
variable "userIPs" {
    type = string
}

# This will be retreived from instance metat-data to set the correct CBCI version
# [TODO] update the user data script to to retrieve and update install version.
variable "appVersion" {
    type = string
    default = "2.440.1.3"
}


# Create OC instance
resource "aws_instance" "cjoc" {
  ami = "ami-01746d0f29f0ba13d"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.oam_traffic.name]
  key_name = aws_key_pair.mykeypair.key_name
  user_data = <<EOF
    #!/bin/bash
    yum install java-11-openjdk -y
    yum install daemonize -y
    yum install wget -y
    yum install epel-release -y 
    wget -c https://downloads.cloudbees.com/cloudbees-core/traditional/operations-center/rolling/rpm/RPMS/noarch/cloudbees-core-oc-2.361.2.1-1.1.noarch.rpm
    rpm -ivh cloudbees-core-oc-2.361.2.1-1.1.noarch.rpm
    systemctl enable cloudbees-core-oc
    systemctl start cloudbees-core-oc

  EOF
  tags = {
    owner = "mawuku"
    CB_VERSION = var.appVersion
  }
}

# Create controller instance
resource "aws_instance" "controller" {
  ami = "ami-01746d0f29f0ba13d"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.oam_traffic.name]
  key_name = aws_key_pair.mykeypair.key_name
  user_data = <<EOF
    #!/bin/bash
    yum install java-11-openjdk -y
    yum install daemonize -y
    yum install wget -y
    yum install epel-release -y 
    wget -c https://downloads.cloudbees.com/cloudbees-core/traditional/client-master/rolling/rpm/RPMS/noarch/cloudbees-core-cm-2.361.2.1-1.1.noarch.rpm
    rpm -ivh cloudbees-core-cm-2.361.2.1-1.1.noarch.rpm
    systemctl enable cloudbees-core-cm
    systemctl start cloudbees-core-cm

  EOF
  tags = {
    owner = "mawuku"
    CB_VERSION = var.appVersion
  }
}

# Security group for web traffic & OAM
resource "aws_security_group" "oam_traffic" {
  name = "Allow HTTP/HTTPS"

    dynamic "ingress" {
      iterator = port
      for_each = var.ingressrules
      content {
        from_port = port.value
        to_port = port.value
        protocol = "-1"
        # CHange this to a variable
        cidr_blocks = [var.userIPs] 
        self = true
      }

  
  }

  dynamic "egress" {
    iterator = port
    for_each = var.egressrules
    content {
      from_port = 0
      to_port = 0
      protocol = "-1"
      # CHange this to a variable
      cidr_blocks = [var.userIPs]
      self = true
    }
    
  }

}

# public key
resource "aws_key_pair" "mykeypair" {
  key_name   = "instancekey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
}
