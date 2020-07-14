//entering ami's at the run time
variable "wp_img" {
  type = string
}


variable "mysql_img" {
  type = string
}

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
resource "aws_internet_gateway" "main" {
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
    gateway_id = "${aws_internet_gateway.main.id}"
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


//launching instance of wordpress
resource "aws_instance" "my_wordpress" {
ami = "${var.wp_img}"
instance_type = "t2.micro"
key_name = "task3"
subnet_id = "${aws_subnet.subnet1.id}"
security_groups = ["${aws_security_group.wp_sg.id}"]

tags = {
   Name = "my-wordpress"
  }
}

//launching instance of mysql
resource "aws_instance" "testmysql" {
ami = "${var.mysql_img}"
instance_type = "t2.micro"
key_name = "task3"
subnet_id = "${aws_subnet.subnet2.id}"
security_groups = ["${aws_security_group.mysql_sg.id}"]

tags = {
   Name  = "testmysql"
  }
}
