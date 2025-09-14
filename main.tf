terraform {
    backend "s3" {
    bucket          = "s3-devops-tf-state"
    key             = "tf-infra/terraform.tfstate"
    region          = "us-east-1"
    dynamodb_table  = "terraform-state-lock"
    encrypt         = true
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.12.0"
    }
  }
}


# SIMPLE INFRASTRUCTURE BUILD:
data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# Create Route-53
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.www_record_name
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
  subnets = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_security_group" "alb" {
  name = "alb-security-group"
  vpc_id = data.aws_vpc.default_vpc.id

   # allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
    Env  = "prod"
  }
}

resource "aws_lb_listener" "lb_listener" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main_loadbalancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_loadbalancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    # if https exists, redirect to https, else forward to TG
    type = var.certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.certificate_arn == "" ? [1] : []
      content {
        target_group {
          arn = aws_lb_target_group.lb_target_group.arn
        }
      }
    }
  }
}

resource "aws_lb_target_group" "lb_target_group" {
  name     = "tf-app-lb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }
}

# Creating the EC2 Instances
resource "aws_security_group" "instances" {
  name = "instance-security-group"
  vpc_id = data.aws_vpc.default_vpc.id
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_instance" "web_server" {
  count = 2
  ami      = var.ec2Ami
  instance_type = var.ec2machinetype
  subnet_id     = data.aws_subnets.default.ids[count.index]
  vpc_security_group_ids = [aws_security_group.instances.id]
  user_data_base64 = base64encode(<<-EOF
              #!/bin/bash
              # simple web app serving on 8080
              apt-get update -y
              apt-get install -y python3
              echo "Hello from $(hostname)" > index.html
              python3 -m http.server 8080 &
              #nohup python3 -m http.server 8080 --directory /var/www >/var/log/simple_http.log 2>&1 &
              EOF
  )
    tags = {
      Name = "web-server-${count.index}"
    }
}


resource "aws_lb_target_group_attachment" "attachment" {
  count            = length(aws_instance.web_server)
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id = aws_instance.web_server[count.index].id
  port = 8080
}
