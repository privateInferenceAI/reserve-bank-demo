output "gateway_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.gateway.public_ip
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.main.dns_name
}

output "instance_role_arn" {
  description = "ARN of the IAM instance role attached to the gateway"
  value       = aws_iam_role.ec2.arn
}
