variable "project_name" {
    description = "Project name for tagging"
    type = string
  
}
variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type = string
}

variable "allowed_ssh_cidr" {
    description = "CIDR block allowed to access SSH"
    type        = string
    default     = "0.0.0.0/0"
  
}

