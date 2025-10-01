provider "aws" {
  region  = "us-east-1"
  profile = "self-healing-ec2"
}

locals {
  s3_bucket = aws_s3_bucket.log_bucket.bucket
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "allow_http_only" {
  name        = "allow_http_only"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_only"
  }
}

resource "aws_s3_bucket" "log_bucket" {
  bucket        = "self-healing-logs-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "SelfHealingLogs"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2_self_healing_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_upload_policy" {
  name        = "self-healing-ec2-s3-put-only"
  description = "Allow EC2 to upload logs only to its own log bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:PutObject"
        ],
        Resource : "arn:aws:s3:::${aws_s3_bucket.log_bucket.bucket}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_upload_policy_attachment" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.s3_upload_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_instance" "self_healing_node" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2 (us-east-1)
  instance_type               = var.instance_type
#  key_name                    = var.key_name #can remove this once SSM is fully working
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/../scripts/cloud-init.sh", {
    S3_BUCKET = local.s3_bucket
    slack_webhook = var.slack_webhook_url
  })

  tags = {
    Name = var.instance_name
  }

  vpc_security_group_ids = [aws_security_group.allow_http_only.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "self_healing_ec2_profile"
  role = aws_iam_role.ec2_instance_role.name
}


