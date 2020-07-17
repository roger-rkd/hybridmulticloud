provider "aws" {
     region = "ap-south-1"
     profile = "rkd"
}

resource "aws_security_group" "my-sg" {
  name        = "my-sg"
  description = "Allow port 80, 22 and 2049"
  vpc_id =   "vpc-77ecf11f"
  

  ingress {
    description = "port 80 for http protocol"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "port 22 for ssh protocol"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
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
    Name = "my-sg"
  }
}

resource "tls_private_key" "task2_key" {
  algorithm   = "RSA"
  
}

output "key_ssh" {
    value = tls_private_key.task_keypair.public_key_openssh
}

output "key_pem" {
     value = tls_private_key.task_keypair.public_key_pem
}

resource "aws_key_pair" "task2_key"{
      key_name = "task2_key"
      public_key = tls_private_key.task2_key.public_key_openssh
}

resource "aws_instance" "task2_ins" {
     ami = "ami-0447a12f28fddb066"
     instance_type = "t2.micro"
     availability_zone = "ap-south-1a"
     key_name = "task2_key"
     security_groups = ["${aws_security_group.my-sg.tags.Name}"]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task2_key.private_key_pem
    host     = aws_instance.task2_ins.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y" ,
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
     
 
     tags = {
              Name= "task2_ins" 
            }
}

resource "aws_efs_file_system" "task2_efs" {
  
  creation_token = "task2_efs"

  tags = {
    Name = "task2_efs"
  }
}

resource "aws_efs_mount_target" "alpha" {
  depends_on = [aws_efs_file_system.task2_efs]
  file_system_id = "${aws_efs_file_system.task2_efs.id}"
  subnet_id      = "${aws_instance.task2_instance.subnet_id}"
  security_groups= ["${aws_security_group.my-sg.id}"]
}

resource "null_resource" "nullres1"  {
 depends_on = [ aws_efs_mount_target.alpha]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task2_key.private_key_pem
    host     = aws_instance.task2_ins.public_ip
  }
  provisioner "remote-exec" {
      inline = [
        "sudo echo ${aws_efs_file_system.task2_efs.dns_name}:/var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
        "sudo mount  ${aws_efs_file_system.task2_efs.dns_name}:/  /var/www/html",
        "sudo curl https://github.com/roger-rkd/hybridmulticloud/blob/master/Task%202/mahi.html > mahi.html",     
        "sudo cp code.html  /var/www/html/"
      ]
  }
}


resource "aws_s3_bucket" "task2-s3mybucket" {
depends_on = [
    null_resource.nullres1,    
  ]     
  bucket = "task2-s3mybucket"
  force_destroy = true
  acl    = "public-read"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::task2-s3mybucket/*"
    }
  ]
}
POLICY
}
resource "aws_s3_bucket_object" "task2-object" {
  depends_on = [ aws_s3_bucket.task2-s3mybucket,
                null_resource.nullres1
               ]
     bucket = aws_s3_bucket.task2-s3mybucket.id
  key    = "someobject"
  source = "C:/Users/Roger!!/Desktop/mahi/mahi.jpg"
  etag = "C:/Users/Roger!!/Desktop/mahi/mahi.jpg"
  acl = "public-read"
  content_type = "image/jpg"
}
locals { 	
  s3_origin_id = "aws_s3_bucket.task2-s3mybucket.id"
}

resource "aws_cloudfront_origin_access_identity" "originidentity" {
     
 }


resource "aws_cloudfront_distribution" "task2-mys3_distribution" {
  origin {
    domain_name = aws_s3_bucket.task2-s3mybucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
           origin_access_identity = aws_cloudfront_origin_access_identity.originidentity.cloudfront_access_identity_path 
     }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "mahi.jpg"

  logging_config {
    include_cookies = false
    bucket          =  aws_s3_bucket.task2-s3mybucket.bucket_domain_name
    
  }



  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
   

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "IN", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}