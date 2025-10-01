output "public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.self_healing_node.public_ip
}

output "log_bucket" {
  value = aws_s3_bucket.log_bucket.bucket
}
