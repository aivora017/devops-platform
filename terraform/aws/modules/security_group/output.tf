output "cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  value       = aws_security_group.eks_cluster_sg.id
}

output "nodes_security_group_id" {
  description = "Security group ID for worker nodes"
  value       = aws_security_group.eks_nodes_sg.id
}

output "jenkins_security_group_id" {
  description = "Security group ID for Jenkins EC2 instance"
  value       = aws_security_group.jenkins_sg.id
}

