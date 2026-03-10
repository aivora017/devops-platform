terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "security_groups" {
  source = "./modules/security_group"

  project_name = var.project_name
  vpc_id       = aws_vpc.main.id
  vpc_cidr     = var.vpc_cidr
}

module "eks_cluster" {
  source = "./modules/cluster"

  project_name       = var.project_name
  eks_version        = var.eks_version
  subnet_ids         = [aws_subnet.primary.id, aws_subnet.secondary.id]
  security_group_ids = [module.security_groups.cluster_security_group_id]
}

module "eks_node_group" {
  source = "./modules/node_group"

  project_name       = var.project_name
  cluster_name       = module.eks_cluster.cluster_name
  kubernetes_version = var.eks_version
  subnet_ids         = [aws_subnet.primary.id, aws_subnet.secondary.id]

  instance_type    = var.instance_type
  desired_capacity = var.desired_capacity
  min_capacity     = var.min_capacity
  max_capacity     = var.max_capacity
}

module "jenkins_ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  ami_id            = var.jenkins_ami_id
  instance_type     = var.jenkins_instance_type
  subnet_id         = aws_subnet.primary.id
  key_pair_name     = var.jenkins_key_pair
  security_group_id = module.security_groups.jenkins_security_group_id
  root_volume_size  = var.jenkins_root_volume_size
  root_volume_type  = "gp3"
}
