terraform {
  backend "s3" {
    bucket          = "maigation-devops-tf-state"
    key             = "tf-infra/terraform.tfstate"
    region          = "us-east-1"
    dynamodb_table  = "terraform-state-locking"
    encrypt         = true
  }

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

resource "aws_subnet" "a_subnet" {
  vpc_id            = data.aws_vpc.default_main.id
  availability_zone = "us-east-1a"
  cidr_block        = cidrsubnet(data.aws_vpc.default_main.cidr_block, 4, 1)
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
  subnets            = [aws_subnet.a_subnet.id]
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
