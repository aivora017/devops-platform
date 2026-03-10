variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "key_pair_name" {
  description = "Key pair name for the EC2 instance"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for the EC2 instance"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size for the EC2 instance"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root volume type for the EC2 instance"
  type        = string
  default     = "gp2"
}