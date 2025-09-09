terraform {


  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.12.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# s3 bucket definition for state file
resource "aws_s3_bucket" "terraform_state" {
  bucket          = "maigation-devops-tf-state"
  force_destroy   = true
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
bucket = aws_s3_bucket.terraform_state.id

rule {
  apply_server_side_encryption_by_default {
    sse_algorithm = "AES256"
  }
}
}

# resource for state locking - to prevent multiple cordinators from terrform apply at the same time
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}


# Building infrasture for demo project
# VPC declaration
data "aws_vpc" "default_main" {
  default = true
}

resource "aws_subnet" "main_subnet" {
  vpc_id            = data.aws_vpc.default_main.id
  availability_zone = "us-east-1a"
  cidr_block        = cidrsubnet(data.aws_vpc.default_main.cidr_block, 4, 9)
}

resource "aws_subnet" "secondary_subnet" {
  vpc_id            = data.aws_vpc.default_main.id
  availability_zone = "us-east-1b"
  cidr_block        = cidrsubnet(data.aws_vpc.default_main.cidr_block, 4, 10)
}

# Create Route-53
resource "aws_route53_zone" "primary" {
  name = "maigation.com"
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.maigation.com"
  type    = "A"

  alias {
    name                   = aws_lb.main_loadbalancer.dns_name
    zone_id                = aws_lb.main_loadbalancer.zone_id
    evaluate_target_health = true
  }
}

# Application Load Balancer
resource "aws_lb" "main_loadbalancer" {
  name               = "main-lb-tf"
  load_balancer_type = "application"
  subnets            = [aws_subnet.main_subnet.id, aws_subnet.secondary_subnet.id]
}

resource "aws_lb_target_group" "lb_target_group" {
  name     = "tf-app-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_main.id
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.main_loadbalancer.arn
  port              = "80"

  default_action {
    type             = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# Creating the EC2 Instances
resource "aws_instance" "main_instance" {
  ami             = "ami-011899242bb902164" # Ubuntu 20.04 LTS
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instances.name]
  user_data       = <<-EOF
              #!/bin/bash
              echo "HWelcome Friend" > index.html
              python3 -m http.server 8080 &
              EOF
}

resource "aws_instance" "secondary_instance" {
  ami             = "ami-011899242bb902164"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instances.name]
  user_data       = <<-EOF
              #!/bin/bash
              echo "Welcome Friend, No downtime!!!" > index.html
              python3 -m http.server 8080 &
              EOF
}

resource "aws_security_group" "instances" {
  name = "instance-security-group"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id        = aws_instance.main_instance.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id        = aws_instance.secondary_instance.id
  port             = 8080
}

resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

}

resource "aws_security_group_rule" "allow_alb_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

}

# Creating the Azure Database
resource "aws_db_instance" "db_instance" {
  allocated_storage = 20
  storage_type               = "standard"
  db_name                    = "mydb"
  engine                     = "mysql"
  instance_class             = "db.t3.micro"
  username                   = "user"
  password                   = "password"
  skip_final_snapshot        = true
}
