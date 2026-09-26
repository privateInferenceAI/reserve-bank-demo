# Secrets Manager replaces .env secrets

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project_name}/${var.environment}/db-password"
  description = "RDS postgres master password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

resource "aws_secretsmanager_secret" "litellm_master_key" {
  name        = "${var.project_name}/${var.environment}/litellm-master-key"
  description = "LiteLLM master key"
}

resource "aws_secretsmanager_secret_version" "litellm_master_key" {
  secret_id     = aws_secretsmanager_secret.litellm_master_key.id
  secret_string = var.litellm_master_key
}

resource "aws_secretsmanager_secret" "litellm_salt_key" {
  name        = "${var.project_name}/${var.environment}/litellm-salt-key"
  description = "LiteLLM salt key"
}

resource "aws_secretsmanager_secret_version" "litellm_salt_key" {
  secret_id     = aws_secretsmanager_secret.litellm_salt_key.id
  secret_string = var.litellm_salt_key
}
