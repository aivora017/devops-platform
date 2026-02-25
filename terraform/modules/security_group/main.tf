resource "aws_security_group" "Jenkins" {
    name        = "jenkins"
    description = "Allow Jenkins access"
    vpc_id      = var.vpc_id
    
    ingress {
        description = "Jenkins web interface"
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH access"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.allowed_ssh_cidr]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        name = "${var.project_name}-jenkins-sg"
        project = var.project_name
    }
  
}