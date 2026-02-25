output "public_ip" {
    description = "Public IP address of the Jenkins EC2 instance"
    value       = aws_eip.jenkins.public_ip
  
}

output "instance_id" {
    description = "Instance ID of the Jenkins EC2 instance"
    value       = aws_instance.jenkins.id
  
}