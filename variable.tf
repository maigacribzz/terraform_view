variable "region" {
  description = "This is the main region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "ec2Ami" {
  description = "AMI Image for all EC2 instances"
  type        = string
  default     = "ami-011899242bb902164"
}

variable "ec2machinetype" {
  description = "EC2 machine type"
  type        = string
  default     = "t2.micro"
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS. Leave empty to use HTTP only."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Primary domain (e.g. maigation.com)"
  type        = string
  default     = "webapp.com"
}

variable "www_record_name" {
  description = "Record to create (e.g. www)"
  type        = string
  default     = "www"
}
