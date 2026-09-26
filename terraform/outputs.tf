output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.main.dns_name
}

output "gateway_private_ip" {
  description = "Private IP of the gateway EC2 instance"
  value       = aws_instance.gateway.private_ip
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint"
  value       = aws_db_instance.main.endpoint
}

output "instance_role_arn" {
  description = "ARN of the IAM instance role"
  value       = aws_iam_role.ec2.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for gateway logs"
  value       = aws_cloudwatch_log_group.gateway.name
}
