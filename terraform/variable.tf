variable "aws_region" {
  description = "AWS region"
  type = string
  default = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name for tagging all resources"
  type = string
  default = "devops-platform"
}

variable "vpc_cindr" {
  description = "CIDR block for the VPC"
  type = string
  default = "10.0.0.0/16"
}

variable "subnet_cindr" {
  description = "CIDR block for the subnet"
  type = string
  default = "10.0.0.0/24"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI for ap-southeast-2"
  type = string
  default = "ami-0818a4d7794d429b1"
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type = string
  default = "t3.micro"
}

variable "key_pair_name" {
    description = "Key pair name for the EC2 instance"
    type = string
  
}