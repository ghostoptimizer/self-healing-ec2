#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
HOSTNAME=$(hostname)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
LOG_FILE="/var/log/uptime.log"
S3_BUCKET="self-healing-logs-REPLACE_ME" #<--- Your unique s3 bucket name

aws s3 cp "$LOG_FILE" "s3://$S3_BUCKET/$HOSTNAME/uptime-$TIMESTAMP.log"
