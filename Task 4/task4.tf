//creating VPC
resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-tf"
  }
}

//creating subnet1 in ap-south-1a
resource "aws_subnet" "subnet1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.0.0/24"
  map_public_ip_on_launch = "true"
  availability_zone="ap-south-1a"
  tags = {
    Name = "subnet1"
  }
}

//creating subnet2 in ap-south-1b
resource "aws_subnet" "subnet2" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone="ap-south-1b"
  tags = {
    Name = "subnet2"
  }
}

//creating internet gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "myigw"
  }
}

//creating route table
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.myigw.id}"
  }
 tags = {
    Name = "myrt"
  }
}

//associating route table with the public subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.r.id
}

provider "aws" {
  region = "ap-south-1"
}

//creating security group for the public subnet
resource "aws_security_group" "wp_sg" {
  name        = "wp_sg"
  description = "Allow public to connect wp"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wp_sg"
  }
}

//creating security group for private subnet
resource "aws_security_group" "mysql_sg" {
  name        = "mysql_sg"
  description = "Allow wp to connect mysql"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql_sg"
  }
}

//creating security group for bastion host
resource "aws_security_group" "my_bastion" {
  name        = "my_bastion"
  description = "Allow ssh for bastion host"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "for ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my_bastion"
  }
}

//creating security group for ssh from mysql
resource "aws_security_group" "mysql_allow" {
  name        = "mysql_allow"
  description = "ssh from mysql"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "for ssh"
    security_groups =[ "${aws_security_group.my_bastion.id}" ]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql_allow"
  }
}

//launching instance of wordpress
resource "aws_instance" "my_wordpress" {
ami = "ami-000cbce3e1b899ebd"
instance_type = "t2.micro"
key_name = "mykey1111"
subnet_id = "${aws_subnet.subnet1.id}"
security_groups = ["${aws_security_group.wp_sg.id}"]

tags = {
   Name = "my-wordpress"
  }
}

//launching instance of mysql
resource "aws_instance" "testmysql" {
ami = "ami-08706cb5f68222d09"
instance_type = "t2.micro"
key_name = "mykey1111"
subnet_id = "${aws_subnet.subnet2.id}"
security_groups = ["${aws_security_group.mysql_sg.id}","${aws_security_group.mysql_allow.id}"]

tags = {
   Name  = "testmysql"
  }
}

//launching instance for bastion host
resource "aws_instance" "bastion" {
ami = "ami-0732b62d310b80e97"
instance_type = "t2.micro"
key_name = "mykey1111"
availability_zone = "ap-south-1a"
subnet_id = "${aws_subnet.subnet1.id}"
security_groups = [ "${aws_security_group.my_bastion.id}" ]

tags = {
Name = "my-bastion"
    }
}

//creating an elastic IP for NAT
resource "aws_eip" "my_eip" {
vpc = true
depends_on = ["aws_internet_gateway.myigw"]

tags = {
Name = "my-eip"
    }
}

//using a NAT gateway
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = "${aws_eip.my_eip.id}"
  subnet_id     = "${aws_subnet.subnet1.id}"

  tags = {
    Name = "my-nat-gateway"
  }
}

//creating route table for NAT
resource "aws_route_table" "r2" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.my_nat_gateway.id}"
  }
    tags = {
    Name = "nat-r2"
  }
}


//associating the route table with private subnet
resource "aws_route_table_association" "b" {
subnet_id      = aws_subnet.subnet2.id
route_table_id = "${aws_route_table.r2.id}"
}
