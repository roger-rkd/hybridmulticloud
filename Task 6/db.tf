#K8s as provider
provider "kubernetes"{
    config_context_cluster="minikube"
}

#aws as provider
provider "aws"{
    region="ap-south-1"
    profile="rkd"
}

data "aws_vpc" "def_vpc"{
    default=true
}

data "aws_subnet_ids" "vpc_sub"{
    vpc_id = data.aws_vpc.def_vpc.id
}

resource "aws_security_group" "allow_sql" {
  name        = "mydb-sg"
  description = "Allow sql"
  vpc_id      = data.aws_vpc.def_vpc.id

  ingress {
    description = "for sql"
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
    Name = "mydb-sg"
  }
}
resource "aws_db_subnet_group" "sub_ids" {
  name       = "main"
  subnet_ids = data.aws_subnet_ids.vpc_sub.ids

  tags = {
    Name = "DB subnet group"
  }
}

resource "aws_db_instance" "my-db" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "rkd"
  password             = "ThalaDhoni07"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name   = aws_db_subnet_group.sub_ids.id
  vpc_security_group_ids = [aws_security_group.allow_sql.id]
  publicly_accessible  = true
  skip_final_snapshot  = true
}

resource "kubernetes_deployment" "wp-deploy"{
     depends_on = [
    aws_db_instance.my-db
    ]
    metadata{
        name="wordpress-deploy"
    }
    spec{
        replicas=1
        selector{
            match_labels={
                env="production"
                region="IN"
                app="wordpress"
            }
        }
        template{
            metadata {
                labels={
                    env="production"
                    region="IN"
                    app="wordpress"
                }
            }
            spec{
                container{
                    image="wordpress:4.8-apache"
                    name="mywp-con"
                
                env {
                    name = "WORDPRESS_DB_HOST"
                    value = aws_db_instance.my-db.endpoint
                }
                env {
                    name = "WORDPRESS_DB_DATABASE"
                    value = aws_db_instance.my-db.name 
                }
                env {
                    name = "WORDPRESS_DB_USER"
                    value = aws_db_instance.my-db.username
                }
                env {
                    name = "WORDPRESS_DB_PASSWORD"
                    value = aws_db_instance.my-db.password
                }
                port {
                    container_port = 80
                }
            }
        }    
    }
}
}
resource "kubernetes_service" "wordpress"{
     depends_on = [
    kubernetes_deployment.wp-deploy,
  ]
  metadata{
        name="wordpress"
        }
    spec{
    selector={
        app = "wordpress"
        }
        port{
            node_port=31002
            port=80
            target_port=80
        }
        type="NodePort"
        }
    }

# open on chrome
resource "null_resource" "openwebsite"  {
depends_on = [
    kubernetes_service.wordpress
  ]
	provisioner "local-exec" {
	    command = "minikube service ${kubernetes_service.wordpress.metadata[0].name}"
  	}
}
