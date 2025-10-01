#!/bin/bash
SERVICE="nginx"
LOG_FILE="/var/log/uptime.log"
SLACK_WEBHOOK_URL=$(cat /opt/self-healing/.slack_webhook)  # optional
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

if systemctl is-active --quiet $SERVICE; then
    echo "$TIMESTAMP - $SERVICE is healthy." >> "$LOG_FILE"
else
    echo "$TIMESTAMP - $SERVICE is DOWN. Restarting..." >> "$LOG_FILE"
    systemctl restart $SERVICE

    # optional Slack alert
    curl -X POST -H 'Content-type: application/json' \
         --data "{\"text\":\"🚨 $SERVICE was down and auto-restarted at $TIMESTAMP on $(hostname)\"}" \
         "$SLACK_WEBHOOK_URL"
fi
