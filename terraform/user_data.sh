#!/bin/bash
set -euo pipefail

# Bootstrap script for the gateway EC2 instance.
# In production this would be replaced by an AMI build or configuration management.

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y docker.io docker-compose-plugin git curl jq

# Clone the project and run it
mkdir -p /opt/reserve-bank-demo
cd /opt/reserve-bank-demo
git clone https://github.com/privateInferenceAI/reserve-bank-demo.git .

# NOTE: In production, secrets come from AWS Secrets Manager or the instance role,
# not from a static .env file. This bootstrap is for demonstration only.
cp .env.example .env
# ... secrets would be injected here ...

docker compose up -d
