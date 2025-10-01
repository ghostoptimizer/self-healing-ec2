#!/bin/bash
set -euxo pipefail

 
# Create needed directories
mkdir -p /opt/self-healing
LOG_FILE="/var/log/uptime.log"
SLACK_WEBHOOK_FILE="/opt/self-healing/.slack_webhook"
HEALTH_CHECK_SCRIPT="/opt/self-healing/health_check.sh"
PUSH_LOGS_SCRIPT="/opt/self-healing/push_logs_to_s3.sh"

# Install essential packages
yum update -y
amazon-linux-extras install nginx1 -y
yum install -y aws-cli amazon-ssm-agent

# Start and enable services
systemctl enable --now nginx
systemctl enable --now amazon-ssm-agent

# Fetch Slack Webhook from injected variable
echo "${slack_webhook}" > "$SLACK_WEBHOOK_FILE"
chmod 600 "$SLACK_WEBHOOK_FILE"
chown ec2-user:ec2-user "$SLACK_WEBHOOK_FILE"

# Health Check Script
cat << 'EOF' > "$HEALTH_CHECK_SCRIPT"
#!/bin/bash
SERVICE="nginx"
LOG_FILE="/var/log/uptime.log"
SLACK_WEBHOOK_URL=$(cat /opt/self-healing/.slack_webhook)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

if systemctl is-active --quiet "$SERVICE"; then
  echo "$TIMESTAMP - $SERVICE is healthy." >> "$LOG_FILE"
else
  echo "$TIMESTAMP - $SERVICE is DOWN. Restarting..." >> "$LOG_FILE"
  systemctl restart "$SERVICE"
  curl -X POST -H 'Content-type: application/json' \
       --data "{\"text\":\"🚨 $SERVICE was down and auto-restarted at $TIMESTAMP on $(hostname)\"}" \
       "$SLACK_WEBHOOK_URL"
fi
EOF

chmod +x "$HEALTH_CHECK_SCRIPT"

# 5. Health Check systemd service
cat << EOF > /etc/systemd/system/health_check.service
[Unit]
Description=Health check for nginx
After=network.target

[Service]
Type=oneshot
ExecStart=$HEALTH_CHECK_SCRIPT
EOF


# Timer to run every 5 min
cat << EOF > /etc/systemd/system/health_check.timer
[Unit]
Description=Runs nginx health check every 5 minutes

[Timer]
OnBootSec=30sec
OnUnitActiveSec=5min
Unit=health_check.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now health_check.timer

# push_logs_to_s3.sh (note: S3_BUCKET must be injected by Terraform templatefile)
cat << 'EOF' > "$PUSH_LOGS_SCRIPT"
#!/bin/bash
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
HOSTNAME=$(hostname)
TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
LOG_FILE="/var/log/uptime.log"
S3_BUCKET="__S3_BUCKET__"  # placeholder to be replaced by templatefile()

aws s3 cp "$LOG_FILE" "s3://$S3_BUCKET/$HOSTNAME/uptime-$TIMESTAMP.log"
EOF

chmod +x "$PUSH_LOGS_SCRIPT"
