#!/bin/bash
set -euo pipefail

# Fetch the webhook securely from SSM Parameter Store
export TF_VAR_slack_webhook_url=$(aws ssm get-parameter \
  --name "/self-healing/slack-webhook" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --profile self-healing-ec2)

# Destroy your Terraform stack using any extra flags you pass in
terraform destroy "$@"
