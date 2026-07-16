resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "portfolio-vpc"
  }
  
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "portfolio-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "portfolio-private-subnet"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "portfolio-igw"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "portfolio-public-rt"
  }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_security_group" "web" {
  name        = "portfolio-web-sg"
  description = "Aprueba http publico y SSH solo desde mi ip"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["201.241.101.159/32"]# Ip Publica de mi equipo
  }

    egress {
        description = "Aprueba trafico saliente a cualquier destino"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
  
    }
    tags = {
    Name = "portfolio-web-sg"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
resource "aws_instance" "web" {
    ami           = data.aws_ami.amazon_linux.id
    instance_type = "t3.micro"
    subnet_id     = aws_subnet.public.id
    vpc_security_group_ids = [aws_security_group.web.id]
    key_name     = aws_key_pair.deployer.key_name
    user_data     = file("user_data.sh")
    user_data_replace_on_change = true
    
    tags = {
        Name = "portfolio-web-server"
    }
}

resource "aws_key_pair" "deployer" {
  key_name   = "portfolio-key"
  public_key = file("portfolio-key.pub")
}
resource "random_id" "bucket_suffix" {
  byte_length = 4
}
resource "aws_s3_bucket" "assets" {
  bucket = "portfolio-web-assets-${random_id.bucket_suffix.hex}"
  tags = {
    Name = "portfolio-web-assets"
  }
}
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_object" "sample_asset" {
  bucket = aws_s3_bucket.assets.id
  key    = "hello.txt"
  source = "assets/hello.txt"
  etag   = filemd5("assets/hello.txt")
}