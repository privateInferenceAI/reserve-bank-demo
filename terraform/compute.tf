# EC2 gateway instance in private subnet

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/${var.project_name}/gateway"
  retention_in_days = 7
}

resource "aws_instance" "gateway" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.ec2_key_name

  user_data = templatefile("${path.module}/user_data.sh", {
    project_name         = var.project_name
    environment          = var.environment
    db_secret_arn        = aws_secretsmanager_secret.db_password.arn
    master_key_arn       = aws_secretsmanager_secret.litellm_master_key.arn
    salt_key_arn         = aws_secretsmanager_secret.litellm_salt_key.arn
    db_host              = aws_db_instance.main.address
    cloudwatch_log_group = aws_cloudwatch_log_group.gateway.name
  })

  tags = {
    Name = "${var.project_name}-gateway"
  }
}
