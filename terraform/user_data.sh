#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Install CloudWatch agent, Docker, AWS CLI, git
apt-get update
apt-get install -y docker.io docker-compose-plugin git curl jq awscli amazon-cloudwatch-agent

# Clone project
cd /opt
mkdir -p reserve-bank-demo
cd reserve-bank-demo
git clone https://github.com/privateInferenceAI/reserve-bank-demo.git .

# Use the Terraform-specific compose file (no local Postgres, binds 0.0.0.0:4000)
cp terraform/docker-compose.terraform.yml docker-compose.yml

# Pull secrets from Secrets Manager and write .env
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "${db_secret_arn}" --query SecretString --output text)
MASTER_KEY=$(aws secretsmanager get-secret-value --secret-id "${master_key_arn}" --query SecretString --output text)
SALT_KEY=$(aws secretsmanager get-secret-value --secret-id "${salt_key_arn}" --query SecretString --output text)

cat > .env <<ENVEOF
DATABASE_URL=postgresql://litellm:$DB_PASSWORD@${db_host}:5432/litellm
LITELLM_MASTER_KEY=$MASTER_KEY
LITELLM_SALT_KEY=$SALT_KEY
AWS_REGION=us-east-1
ENVEOF

chmod 600 .env

# Configure CloudWatch agent for Docker logs
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'AGENTEOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/docker.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
AGENTEOF

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Start gateway
docker compose up -d
