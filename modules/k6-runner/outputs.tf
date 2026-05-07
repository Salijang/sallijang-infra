output "instance_id" {
  description = "k6 runner EC2 instance ID."
  value       = try(aws_instance.this[0].id, null)
}

output "private_ip" {
  description = "k6 runner private IP."
  value       = try(aws_instance.this[0].private_ip, null)
}

output "public_ip" {
  description = "k6 runner public IP, if enabled."
  value       = try(aws_instance.this[0].public_ip, null)
}

output "security_group_id" {
  description = "k6 runner security group ID."
  value       = try(aws_security_group.this[0].id, null)
}

output "instance_profile_name" {
  description = "k6 runner instance profile name."
  value       = try(aws_iam_instance_profile.this[0].name, null)
}
