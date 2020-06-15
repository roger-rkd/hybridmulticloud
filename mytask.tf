provider "aws" {
     region = "ap-south-1"
     profile = "mkn"
}

resource "aws_security_group" "task_security_group" {
  name        = "task_security_group"
  description = "Allow port 80 and 22"
  

  ingress {
    description = "port 80 for http protocol"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "port 20 for ssh protocol"
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
    Name = "task_security_group"
  }
}

resource "tls_private_key" "task_keypair" {
  algorithm   = "RSA"
  
}
output "key_ssh" {
    value = tls_private_key.task_keypair.public_key_openssh
}

output "key_pem" {
     value = tls_private_key.task_keypair.public_key_pem
}

resource "aws_key_pair" "task_keypair"{
      key_name = "task_keypair"
      public_key = tls_private_key.task_keypair.public_key_openssh
}

resource "aws_instance" "task_instance" {
     ami = "ami-0447a12f28fddb066"
     instance_type = "t2.micro"
     availability_zone = "ap-south-1a"
     key_name = aws_key_pair.task_keypair.key_name
     security_groups = ["${aws_security_group.task_security_group.tags.Name}"]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task_keypair.private_key_pem
    host     = aws_instance.task_instance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
     
 
     tags = {
              Name= "task_instance" 
            }
}

resource "aws_ebs_volume" "task_harddrive" {
  availability_zone = "ap-south-1a"
  size              = 100

  tags = {
    Name = "task_harddrive"
  }
}

resource "aws_volume_attachment" "task_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.task_harddrive.id
  instance_id = aws_instance.task_instance.id
  force_detach = true
}

resource "null_resource" "partition"  {

depends_on = [
    aws_volume_attachment.task_attach
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task_keypair.private_key_pem
    host     = aws_instance.task_instance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/mannat1999/multicloud.git /var/www/html"
    ]
  }
}
resource "aws_s3_bucket" "highlevelbucket" {
  bucket = "highlevelbucket"
  acl    = "public-read"

  tags = {
    Name        = "highlevelbucket"
    
  }
}


resource "aws_cloudfront_distribution" "s3_distribution" {
          enabled = true
          is_ipv6_enabled = true

   origin {
    domain_name = "${aws_s3_bucket.highlevelbucket.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.highlevelbucket.id}"
     }
 restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.highlevelbucket.id}"
   
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

 viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 120
    max_ttl                = 86400
  }


viewer_certificate {
    cloudfront_default_certificate = true
  }
}