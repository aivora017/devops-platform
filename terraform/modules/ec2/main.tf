resource "aws_instance" "jenkins" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
  }
  
  tags = {
    name = "${var.project_name}-jenkins"
    project = var.project_name
  }
}

