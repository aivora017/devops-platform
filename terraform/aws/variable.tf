variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project_name" {
  type    = string
  default = "devops-platform"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "primary_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "secondary_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "eks_version" {
  type    = string
  default = "1.30"
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 3
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "jenkins_ami_id" {
  description = "AMI ID for Jenkins EC2 instance (Ubuntu 22.04 LTS)"
  type        = string
  default     = "ami-0818a4d7794d429b1"  # Ubuntu 22.04 LTS in ap-southeast-2 (updated Feb 2026)
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins"
  type        = string
  default     = "t3.micro"  # Burstable instance for low resource needs
}

variable "jenkins_key_pair" {
  description = "SSH key pair name for Jenkins EC2 instance"
  type        = string
  default     = "devops-platform"
}

variable "jenkins_root_volume_size" {
  description = "Root volume size for Jenkins in GB"
  type        = number
  default     = 50
}