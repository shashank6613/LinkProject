terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ----------------------
# Networking (VPC)
# ----------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "link-project-vpc" }
}

# Public subnets (2)
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[each.key % length(var.availability_zones)]
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-${each.key}" }
}

# Private subnets (2)
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[each.key % length(var.availability_zones)]
  map_public_ip_on_launch = false

  tags = { Name = "private-subnet-${each.key}" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "project-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Security Groups ------------------------------

# SG for EKS nodes -----------------------------
resource "aws_security_group" "eks_nodes" {
  name   = "sg-eks-nodes"
  vpc_id = aws_vpc.this.id
  description = "EKS worker nodes security group"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-eks-nodes" }
}

# SG for Master EC2 ----------------------------
resource "aws_security_group" "master_ec2" {
  name   = "sg-master-ec2"
  vpc_id = aws_vpc.this.id
  description = "Master EC2 SG: allows access to RDS and EKS nodes"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # restrict to your IP in prod
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-master-ec2" }
}

# SG for RDS -------------------------------
resource "aws_security_group" "rds_sg" {
  name   = "sg-rds"
  vpc_id = aws_vpc.this.id
  description = "Allow postgres access from EKS nodes and master EC2"

  # Allow Postgres from EKS nodes SG
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
    description     = "Postgres from EKS nodes"
  }

  # Allow Postgres from master EC2 SG
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.master_ec2.id]
    description     = "Postgres from master EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-rds" }
}


# IAM Roles & Policies

# EKS cluster role--------------------------------------

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role-${random_id.ekscid.hex}"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_A" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Node role for managed node group
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role-${random_id.eksnid.hex}"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_A" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Master EC2 IAM role with S3 read permission

resource "aws_iam_role" "master_ec2_role" {
  name = "master-ec2-role-${random_id.masterid.hex}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy" "master_s3_get" {
  name = "master-s3-get-policy"
  role = aws_iam_role.master_ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::twentyseventhbucket/*"]
      }
    ]
  })
}
resource "aws_iam_instance_profile" "master_profile" {
  name = "master-profile-${random_id.masterid.hex}"
  role = aws_iam_role.master_ec2_role.name
}

# random ids for unique names
resource "random_id" "ekscid" { byte_length = 4 }
resource "random_id" "eksnid"  { byte_length = 4 }
resource "random_id" "masterid"{ byte_length = 4 }


# RDS: subnet group, primary + replica

resource "aws_db_subnet_group" "rds_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = values(aws_subnet.private)[*].id
  tags = { Name = "rds-subnet-group" }
}

resource "aws_db_instance" "primary" {
  identifier             = var.primary_rds_identifier
  engine                 = "postgres"
  engine_version         = "13.9"   # adjust as needed
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  parameter_group_name   = "newpara"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  multi_az               = false
  skip_final_snapshot    = true
}

# Read replica ----------------------------------------

resource "aws_db_instance" "replica" {
  identifier            = var.replica_rds_identifier
  engine                = aws_db_instance.primary.engine
  instance_class        = "db.t3.micro"
  parameter_group_name  = "newpara"
  replicate_source_db   = aws_db_instance.primary.id
  db_subnet_group_name  = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible   = false
  multi_az              = false
  skip_final_snapshot   = true
}

# EKS Cluster --------------------------------------------

resource "aws_eks_cluster" "cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids         = concat(values(aws_subnet.private)[*].id, values(aws_subnet.public)[*].id)
    endpoint_public_access = true
    security_group_ids  = [aws_security_group.eks_nodes.id]
  }

  version = var.eks_version

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_A
  ]
}

# Managed Node group for EKS ------------------------------

resource "aws_eks_node_group" "managed_nodes" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.eks_cluster_name}-ng"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = values(aws_subnet.private)[*].id

  scaling_config {
    desired_size = var.node_group_desired
    min_size     = var.node_group_min
    max_size     = var.node_group_max
  }

  instance_types = [var.node_instance_type]
  ami_type       = "AL2_x86_64"

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_A,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr_readonly,
    aws_eks_cluster.cluster
  ]
}


# Master EC2 instance --------------------------------------

resource "aws_instance" "master" {
  ami                    = var.master_ec2_ami
  instance_type          = var.master_ec2_instance_type
  subnet_id              = values(aws_subnet.public)[0].id
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.master_ec2.id]

  iam_instance_profile   = aws_iam_instance_profile.master_profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -xe
    if ! command -v aws &> /dev/null; then
      apt-get update -y
      apt-get install -y awscli
    fi
    aws s3 cp s3://twentyseventhbucket/Link-Project/link-ec2-tool.sh /home/ubuntu/link-ec2-tool.sh --region ${var.aws_region}
    aws s3 cp s3://twentyseventhbucket/Link-Project/link-tool-check.sh /home/ubuntu/link-tool-check.sh --region ${var.aws_region}
    
    chmod +x /home/ubuntu/link-ec2-tool.sh /home/ubuntu/link-tool-check.sh

    /home/ubuntu/link-ec2-tool.sh
    /home/ubuntu/link-tool-check.sh
  EOF

  tags = { Name = "Master-EC2" }
}


# Outputs -------------------------------------------------------------

output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = values(aws_subnet.private)[*].id
}

output "public_subnet_ids" {
  value = values(aws_subnet.public)[*].id
}

output "primary_db_endpoint" {
  value = aws_db_instance.primary.address
}

output "replica_db_endpoint" {
  value = aws_db_instance.replica.address
}

output "eks_cluster_name" {
  value = aws_eks_cluster.cluster.name
}

output "master_ec2_id" {
  value = aws_instance.master.id
}
