output "jenkins_public_ip" {
  description = "Public IP of Jenkins server"
  value       = module.ec2.public_ip
}

output "jenkins_url" {
  description = "Jenkins web interface URL"
  value       = "http://${module.ec2.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = "ssh -i ~/.ssh/devops-platform.pem ubuntu@${module.ec2.public_ip}"
}