output "vpc_id" {
  description = "The ID of the AWS VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
    description = "The ID of the public subnet"
    value       = aws_subnet.public.id
  
}