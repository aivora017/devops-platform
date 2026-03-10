output "eks_cluster_name" {
  description = "Cluster name"
  value       = module.eks_cluster.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Cluster API endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "eks_cluster_version" {
  description = "Cluster version"
  value       = module.eks_cluster.cluster_version
}

output "eks_cluster_arn" {
  description = "Cluster ARN"
  value       = module.eks_cluster.cluster_arn
}

output "eks_node_group_id" {
  description = "Node group ID"
  value       = module.eks_node_group.node_group_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks_cluster.cluster_name} --region ${var.aws_region}"
}

output "jenkins_public_ip" {
  description = "Jenkins public IP"
  value       = module.jenkins_ec2.public_ip
}

output "jenkins_instance_id" {
  description = "Jenkins instance ID"
  value       = module.jenkins_ec2.instance_id
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${module.jenkins_ec2.public_ip}:8080"
}