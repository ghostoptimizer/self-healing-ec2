I just started learning cloud about a week ago — and this project became my hands-on crash course in infrastructure, automation, and reliability.

Through building it, I learned:
	•	Why self-healing matters (for uptime, customer trust, and scaling)
	•	How to use Terraform to declaratively launch and control infrastructure
	•	How to combine Bash, cloud-init, and systemd to build automated healing logic
	•	How to track and alert via Slack and S3 without hardcoding secrets

It’s helped me go from “I don’t get cloud” to “I can build something reliable” — and this is just the beginning.

🔗 Here are some beginner-friendly resources that helped me understand cloud infrastructure:
(Add your favorite blog posts, YouTube videos, or docs here)



Plan:

✅Phase 1: EC2 Infrastructure with Terraform
What’s the mission?

Layout:
├── terraform/
│   ├── main.tf  # Core infrastructure resources.
│   ├── variables.tf # Inputs like instance type, AMI ID, key name, etc.
│   ├── outputs.tf # Useful outputs like instance public IP.
│   └── cloud-init.sh # Script to install & start a service.
├── README.md

Before you can heal an EC2 instance, you need to control it:
	•	Launch it declaratively (Terraform)
	•	Inject software at boot time (cloud-init)
	•	Secure it (SSH, firewall)
	•	Observe it (output IP, track status)

What we’ll do:
	1.	Provision an EC2 instance using Terraform
	2.	Use cloud-init to install a web app (e.g., Nginx or a fake service)
	3.	Attach a security group for port 80 (HTTP)
STACK OVERVIEW:
	•	Terraform: Infrastructure as Code (IaC)
	•	EC2: The machine we self-heal
	•	cloud-init: Executes shell code on first boot (provisioning via userdata)
	•	Security Group: Firewall that exposes only what you need
	•	Key Pair: SSH access for inspection/debugging
	•	Outputs: See the public IP & connect

🧠 LESSONS FROM PHASE 1
	•	✅ We use terraform for idempotent, repeatable, infrastructure-as-code
	•	✅ cloud-init gives us lightweight service provisioning at launch
	•	✅ aws_security_group is a firewall, keep it locked down in prod
	•	✅ Outputs give us inspectable values we can feed into scripts or other modules
NGINX IP website image:
/Users/burnt_jello/Desktop/self-healing-ec2nginx.png	

✅ Phase 2: Bash-Based Health Check

What we’ll do:
	1.	Add a health_check.sh that:
	•	Checks if the service is running
	•	Restarts it if down
	•	Logs to uptime.log
	•	Sends a Slack alert using webhook

Concept                Why It Matters
--------------------------------------
systemd timer           Native Linux scheduler — more reliable than cron for services

Bash health checks      How SREs keep services alive without 3rd party agents

Slack webhook alerts    External visibility & alerting pipeline

Log file tracking       Simple observability: lets you track uptime history

scripts/
│   ├── health_check.sh       # Heartbeat check script
│   └── send_slack_alert.sh   # Slack Webhook script (called from above)


SSH = alias ssh-healer='ssh -i ~/Downloads/self-healing-ec2.pem ec2-user@<IP>'
            ----------
            shortcut

I use an IAM Role attached to the EC2 instance.
This role will act on behalf of the EC2, and grant it permission to access S3.

Why? Your EC2 instance is just a virtual machine, by default, it has no permission to access anything, even in the same AWS account.
✅ Upload files to S3 (e.g., logs, health alerts, backups)
❌ Without manually configuring AWS CLI keys (that’s insecure and bad practice)

IAM allowed ec2 to acces s3 to creat buckets for the


Bonus: Use systemd to schedule health check every 5 minutes.

✅ Phase 3: Slack Integration
	•	Use your Slack Webhook to notify on failure and restart
	•	Format message with emoji/status/time

> “I configured an S3 bucket to store uptime logs, and granted my EC2 instance the necessary permissions using an IAM instance profile with the AmazonS3FullAccess policy. This allows the instance to push logs to S3 directly without embedding static credentials.”

> “I set up Slack alerting using an Incoming Webhook integration. The health_check.sh script posts alerts to a specific channel whenever Nginx is detected as down. It also restarts the service automatically.”

> “Nginx health is being tracked locally through a structured log file at /var/log/uptime.log. The health check runs every 5 minutes using a systemd timer, logging whether the service is healthy or if it was restarted.”

That wraps up Phase 3, where the infrastructure is now:

	•	Self-monitoring
	•	Self-healing
	•	Slack-alerting
	•	Log-persisting to both local disk and cloud storage”

✅ Phase 4: Logging
	•	Store logs locally (/var/log/uptime.log)

now i am removing ssh and replacing it with AWS SSM access for more security 

Since I already have the EC2-local systemd timer handling health_check.sh on a 5-minute interval, I’m thinking we don’t need a Lambda trigger.

Instead, we can create GitHub Actions workflows to:
	•	Manually or periodically run push_logs_to_s3.sh (via SSM)
	•	Optionally trigger health_check.sh externally for testing or demo purposes

This gives us CI/CD-style control over repetitive tasks without duplicating the timer logic in Lambda — and keeps the EC2 responsible for its own self-healing.


create this folder path /opt/self-healing/.slack_webhook and insert my webhook url in there(cloud-init.sh,health_check.sh)

i added the webhook to ssm instead of putting it inside .secrets/ and automated it in a absh script so it runs it secretly in the background so we can just run our terraform script and our alerts our working

First I made sure my credentials were right by running ```aws configure --profile self-healing-ec2```

second i ran the code below and got the output below it:
```
aws ssm put-parameter \
  --name "/self-healing/slack-webhook" \
  --value "your/webhookurl" \
  --type SecureString \
  --profile self-healing-ec2
```

output:
```
{
  "Version": 1,
  "Tier": "Standard"
}
```

third i added a path to it inside of my cloud-init.sh to make sure my ec2 fetches it:
```
SLACK_WEBHOOK=$(aws ssm get-parameter \
  --name "/self-healing/slack-webhook" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)
```
lastly exported it and then tested it:
```
export SLACK_WEBHOOK
curl -X POST -H 'Content-type: application/json' --data '{"text":"✅ Self-healing EC2 booted"}' "$SLACK_WEBHOOK"
```
