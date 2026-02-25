terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
  project_name = var.project_name
  vpc_cindr = var.vpc_cindr
  subnet_cindr = var.subnet_cindr

}

module "security_group" {
    source = "./modules/security_group"
    project_name = var.project_name
    vpc_id = module.vpc.vpc_id
  
}

module "ec2" {
    source = "./modules/ec2"
    project_name = var.project_name
    ami_id = var.ami_id
    instance_type = var.instance_type
    subnet_id = module.vpc.subnet_id
    security_group_id = module.security_group.security_group_id
    key_pair_name = var.key_pair_name
}