variable "aws_region" {
  description = "AWS region for the gateway"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for resources"
  type        = string
  default     = "reserve-bank"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "demo"
}

variable "admin_cidr" {
  description = "Admin IP for bastion SSH access"
  type        = string
}

variable "ec2_key_name" {
  description = "Name of existing EC2 key pair"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "db_password" {
  description = "RDS postgres master password"
  type        = string
  sensitive   = true
}

variable "litellm_master_key" {
  description = "LiteLLM master key"
  type        = string
  sensitive   = true
}

variable "litellm_salt_key" {
  description = "LiteLLM salt key"
  type        = string
  sensitive   = true
}
