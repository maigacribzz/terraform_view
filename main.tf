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

# EC2 instance definition
resource "aws_instance" "example" {
  ami           = "ami-011899242bb902164" # Replace with a valid AMI ID
  instance_type = "t2.micro"
  tags = {
    Name = "EC21.0"
  }
}

# s3 bucket definition
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

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
