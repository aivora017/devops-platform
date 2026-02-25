variable "project_name" {
  description = "Name of the project"
  type        = string
  
}

variable "vpc_cindr" {
  description = "CIDR block for the VPC"
  type        = string
  default = "10.0.0.0/16"
}   

variable "subnet_cindr" {
    description = "CIDR block for the public subnet"
    type        = string    
    default = "10.0.1.0/24"
  
}