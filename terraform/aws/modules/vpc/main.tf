resource "aws_vpc" "main" {
  cidr_block = var.vpc_cindr
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  tags = {
    name = "${var.project_name}-vpc"
    project = var.project_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
 tags = {
    name = "${var.project_name}-igw"
    project = var.project_name
  }
  
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cindr
  map_public_ip_on_launch = true
  tags = {
    name = "${var.project_name}-public-subnet"
    project = var.project_name
  }
}   

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    name = "${var.project_name}-route-table"
    project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}