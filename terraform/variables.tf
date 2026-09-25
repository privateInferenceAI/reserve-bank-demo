variable "aws_region" {
  description = "AWS region for the gateway"
  type        = string
  default     = "us-east-1"
}

variable "admin_cidr" {
  description = "Your admin IP for SSH access, e.g. 203.0.113.10/32"
  type        = string
}

variable "ec2_key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate for the ALB HTTPS listener"
  type        = string
}
