terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~>3.0"
      }
    }
}

# Configure the AWS provider 
provider "aws" {
    region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "MyLab-VPC"{
    cidr_block = var.cidr_block[0]
    tags = {
        Name = "MyLab-VPC"
    }
}

# Create Subnet (Public)
resource "aws_subnet" "MyLab-Subnet1" {
    vpc_id = aws_vpc.MyLab-VPC.id
    cidr_block = var.cidr_block[1]
    tags = {
        Name = "MyLab-Subnet1"
    }
}

# Create Internet Gateway
resource "aws_internet_gateway" "MyLab-IGW" {
    vpc_id = aws_vpc.MyLab-VPC.id
    tags = {
        Name = "MyLab-IGW"
    }
}

# Create Security Group
resource "aws_security_group" "MyLab-SG" {
    name = "MyLab-SG"
    description = "To allow inbound and outbount traffic to MyLab"
    vpc_id = aws_vpc.MyLab-VPC.id
    dynamic ingress {
        iterator = port
        for_each = var.ports
            content {
              from_port = port.value
              to_port = port.value
              protocol = "tcp"
              cidr_blocks = ["0.0.0.0/0"]
            }
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "allow traffic"
    }
}

# Create route table and association
resource "aws_route_table" "MyLab-rtb" {
    vpc_id = aws_vpc.MyLab-VPC.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.MyLab-IGW.id
    }
    tags = {
        Name = "MyLab-rtb"
    }
}

resource "aws_route_table_association" "MyLab-rtba" {
    subnet_id = aws_subnet.MyLab-Subnet1.id
    route_table_id = aws_route_table.MyLab-rtb.id
}

# Create an AWS EC2 Instance to host Jenkins
resource "aws_instance" "Jenkins" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name = "ec2"
  vpc_security_group_ids = [aws_security_group.MyLab-SG.id]
  subnet_id = aws_subnet.MyLab-Subnet1.id
  associate_public_ip_address = true
  user_data = file("./userdata/InstallJenkins.sh")

  tags = {
    Name = "Jenkins-Server"
  }
}

# Create an AWS EC2 Instance to host Ansible Controller
resource "aws_instance" "Ansible-Controller" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name = "ec2"
  vpc_security_group_ids = [aws_security_group.MyLab-SG.id]
  subnet_id = aws_subnet.MyLab-Subnet1.id
  associate_public_ip_address = true
  user_data = file("./userdata/InstallAnsibleController.sh")

  tags = {
    Name = "Ansible-Controller"
  }
}

#Create an AWS EC2 Instance to host Sonatype Nexus
resource "aws_instance" "Nexus" {
  ami           = var.ami
  instance_type = var.instance_type_for_nexus
  key_name = "ec2"
  vpc_security_group_ids = [aws_security_group.MyLab-SG.id]
  subnet_id = aws_subnet.MyLab-Subnet1.id
  associate_public_ip_address = true
  user_data = file("./userdata/InstallNexus.sh")

  tags = {
    Name = "Nexus-Server"
  }
}

#Create an AWS EC2 Instance to host Docker
resource "aws_instance" "DockerHost" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name = "ec2"
  vpc_security_group_ids = [aws_security_group.MyLab-SG.id]
  subnet_id = aws_subnet.MyLab-Subnet1.id
  associate_public_ip_address = true
  user_data = file("./userdata/InstallDocker.sh")

  tags = {
    Name = "DockerHost"
  }
}
