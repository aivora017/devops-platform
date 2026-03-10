output "public_ip" {
  description = "Jenkins public IP"
  value       = aws_eip.jenkins.public_ip
}

output "instance_id" {
  description = "Jenkins instance ID"
  value       = aws_instance.jenkins.id
}