output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks_cluster.cluster_version
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks_cluster.cluster_arn
}

output "eks_node_group_id" {
  description = "EKS node group ID"
  value       = module.eks_node_group.node_group_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl to access EKS cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks_cluster.cluster_name} --region ${var.aws_region}"
}

output "jenkins_public_ip" {
  description = "Public IP address of Jenkins EC2 instance"
  value       = module.jenkins_ec2.public_ip
}

output "jenkins_instance_id" {
  description = "Instance ID of Jenkins EC2 instance"
  value       = module.jenkins_ec2.instance_id
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${module.jenkins_ec2.public_ip}:8080"
}