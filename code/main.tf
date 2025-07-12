provider "aws" {
  region = var.region
}

# VPC and Networking
resource "aws_vpc" "ad_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "AD-VPC"
  }
}

resource "aws_subnet" "ad_subnet" {
  vpc_id            = aws_vpc.ad_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "AD-Subnet"
  }
}

resource "aws_internet_gateway" "ad_igw" {
  vpc_id = aws_vpc.ad_vpc.id

  tags = {
    Name = "AD-IGW"
  }
}

resource "aws_route_table" "ad_rt" {
  vpc_id = aws_vpc.ad_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ad_igw.id
  }

  tags = {
    Name = "AD-RouteTable"
  }
}

resource "aws_route_table_association" "ad_rta" {
  subnet_id      = aws_subnet.ad_subnet.id
  route_table_id = aws_route_table.ad_rt.id
}

resource "aws_security_group" "ad_sg" {
  name        = "ad-security-group"
  description = "Allow RDP, AD, and SQL traffic"
  vpc_id      = aws_vpc.ad_vpc.id

  # RDP access
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production
  }

  # AD DS traffic
  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # LDAP traffic
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # DNS traffic
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Kerberos traffic
  ingress {
    from_port   = 464
    to_port     = 464
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 464
    to_port     = 464
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SMB traffic
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SQL Server traffic
  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AD-SecurityGroup"
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ad_ec2_role" {
  name = "AD-EC2-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ad_ec2_profile" {
  name = "AD-EC2-Profile"
  role = aws_iam_role.ad_ec2_role.name
}

# Domain Controller 1
resource "aws_instance" "dc1" {
  ami                  = data.aws_ami.windows_server_2019.id
  instance_type        = var.instance_type_dc
  subnet_id            = aws_subnet.ad_subnet.id
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ad_ec2_profile.name
  security_groups      = [aws_security_group.ad_sg.id]

  user_data = templatefile("${path.module}/userdata/dc1.tftpl", {
    ad_domain_name       = var.ad_domain_name
    ad_domain_netbios_name = var.ad_domain_netbios_name
  })

  tags = {
    Name = "DC1"
  }
}

# Domain Controller 2
resource "aws_instance" "dc2" {
  ami                  = data.aws_ami.windows_server_2019.id
  instance_type        = var.instance_type_dc
  subnet_id            = aws_subnet.ad_subnet.id
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ad_ec2_profile.name
  security_groups      = [aws_security_group.ad_sg.id]

  depends_on = [aws_instance.dc1]

  user_data = templatefile("${path.module}/userdata/dc2.tftpl", {
    ad_domain_name       = var.ad_domain_name
    ad_domain_netbios_name = var.ad_domain_netbios_name
    dc1_private_ip       = aws_instance.dc1.private_ip
  })

  tags = {
    Name = "DC2"
  }
}

# Application Server
resource "aws_instance" "app_server" {
  ami                  = data.aws_ami.windows_server_2019.id
  instance_type        = var.instance_type_app
  subnet_id            = aws_subnet.ad_subnet.id
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ad_ec2_profile.name
  security_groups      = [aws_security_group.ad_sg.id]

  depends_on = [aws_instance.dc1, aws_instance.dc2]

  user_data = templatefile("${path.module}/userdata/member.tftpl", {
    hostname        = "APP01"
    ad_domain_name  = var.ad_domain_name
    admin_password  = var.admin_password
    dc1_private_ip  = aws_instance.dc1.private_ip
    dc2_private_ip  = aws_instance.dc2.private_ip
  })

  tags = {
    Name = "APP01"
  }
}

# SQL Server
resource "aws_instance" "sql_server" {
  ami                  = data.aws_ami.windows_sql_server_2019.id
  instance_type        = var.instance_type_sql
  subnet_id            = aws_subnet.ad_subnet.id
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ad_ec2_profile.name
  security_groups      = [aws_security_group.ad_sg.id]

  depends_on = [aws_instance.dc1, aws_instance.dc2]

  user_data = templatefile("${path.module}/userdata/member.tftpl", {
    hostname        = "SQL01"
    ad_domain_name  = var.ad_domain_name
    admin_password  = var.admin_password
    dc1_private_ip  = aws_instance.dc1.private_ip
    dc2_private_ip  = aws_instance.dc2.private_ip
  })

  tags = {
    Name = "SQL01"
  }
}

# Workstations (3 instances)
resource "aws_instance" "workstations" {
  count                = 3
  ami                  = data.aws_ami.windows_10.id
  instance_type        = var.instance_type_workstation
  subnet_id            = aws_subnet.ad_subnet.id
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ad_ec2_profile.name
  security_groups      = [aws_security_group.ad_sg.id]

  depends_on = [aws_instance.dc1, aws_instance.dc2]

  user_data = templatefile("${path.module}/userdata/member.tftpl", {
    hostname        = "WS0${count.index + 1}"
    ad_domain_name  = var.ad_domain_name
    admin_password  = var.admin_password
    dc1_private_ip  = aws_instance.dc1.private_ip
    dc2_private_ip  = aws_instance.dc2.private_ip
  })

  tags = {
    Name = "WS0${count.index + 1}"
  }
}

# AMI data sources
data "aws_ami" "windows_server_2019" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

data "aws_ami" "windows_sql_server_2019" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-SQL_2019_Standard-*"]
  }
}

data "aws_ami" "windows_10" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_10_English-Full-Base-*"]
  }
}
