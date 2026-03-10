variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "devops-platform"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "primary_subnet_cidr" {
  description = "Primary subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "secondary_subnet_cidr" {
  description = "Secondary subnet CIDR block"
  type        = string
  default     = "10.0.2.0/24"
}

variable "eks_version" {
  description = "EKS version"
  type        = string
  default     = "1.30"
}

variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "Worker node instance type"
  type        = string
  default     = "t3.small"
}

variable "jenkins_ami_id" {
  description = "Jenkins AMI ID"
  type        = string
  default     = "ami-0818a4d7794d429b1"
}

variable "jenkins_instance_type" {
  description = "Jenkins instance type"
  type        = string
  default     = "t3.small"
}

variable "jenkins_key_pair" {
  description = "Jenkins EC2 key pair name"
  type        = string
  default     = "devops-platform"
}

variable "jenkins_root_volume_size" {
  description = "Jenkins root volume size in GB"
  type        = number
  default     = 50
}