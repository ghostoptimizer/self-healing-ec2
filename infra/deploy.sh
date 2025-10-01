#!/bin/bash

# Fetch the webhook securely from SSM Parameter Store
export TF_VAR_slack_webhook_url=$(aws ssm get-parameter \
  --name "/self-healing/slack-webhook" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --profile self-healing-ec2)

# Apply your Terraform with any extra flags you pass in
terraform apply "$@"
