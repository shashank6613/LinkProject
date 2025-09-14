terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# ------------------------
# AWS Provider
# ------------------------
provider "aws" {
  region = var.aws_region
}

# ------------------------
# VPC + Subnets + IGW
# ------------------------
resource "aws_vpc" "this" {
  cidr_block          = var.vpc_cidr
  enable_dns_support  = true
  enable_dns_hostnames = true
  tags = { Name = "link-project-vpc" }
}

# Public Subnets
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  vpc_id              = aws_vpc.this.id
  cidr_block          = each.value
  availability_zone   = var.availability_zones[each.key % length(var.availability_zones)]
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-${each.key}" }
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  vpc_id              = aws_vpc.this.id
  cidr_block          = each.value
  availability_zone   = var.availability_zones[each.key % length(var.availability_zones)]
  map_public_ip_on_launch = false

  tags = { Name = "private-subnet-${each.key}" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags    = { Name = "project-igw" }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

# Associate route table with public subnets
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}


# ------------------------
# Security Groups
# ------------------------

# SG for EKS Nodes
resource "aws_security_group" "eks_nodes" {
  name        = "eks-nodes-sg"
  vpc_id      = aws_vpc.this.id
  description = "EKS worker nodes SG"

  egress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "eks-nodes-sg" }
}

# SG for EC2 Instance
resource "aws_security_group" "link_ec2" {
  name        = "link-ec2-sg"
  vpc_id      = aws_vpc.this.id
  description = "SG for the EC2 instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "link-ec2-sg" }
}

# SG for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow Postgres access from EKS nodes"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id, aws_security_group.link_ec2.id]
    description     = "Postgres from EKS nodes and EC2"
  }

  egress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg" }
}

# ------------------------
# IAM Roles
# ------------------------

# EKS Cluster Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role-${random_id.ekscid.hex}"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "eks_cluster_A" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Node Role
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role-${random_id.eksnid.hex}"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
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

# EC2 Instance Role with Permissions
resource "aws_iam_role" "link_ec2_role" {
  name = "link-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "link_ec2_policy" {
  name   = "link-ec2-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::your-s3-bucket-name/*"
      },
      {
        Action   = [
          "eks:DescribeCluster",
          "eks:DescribeNodegroup",
          "eks:ListClusters",
          "eks:ListNodegroups",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "rds:DescribeDBInstances"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "link_ec2_policy_attach" {
  role       = aws_iam_role.link_ec2_role.name
  policy_arn = aws_iam_policy.link_ec2_policy.arn
}

resource "aws_iam_instance_profile" "link_ec2_profile" {
  name = "link-ec2-profile"
  role = aws_iam_role.link_ec2_role.name
}


# ALB Controller IAM Policy
data "http" "alb_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.2/docs/install/iam_policy.json"
}
resource "aws_iam_policy" "alb_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy-${var.env}"
  policy = data.http.alb_iam_policy.response_body
}
resource "aws_iam_role" "alb_role" {
  name = "eks-alb-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_role.name
  policy_arn = aws_iam_policy.alb_policy.arn
}

# ------------------------
# RDS (Primary + Replica)
# ------------------------
resource "aws_db_subnet_group" "rds_subnets" {
  name         = "rds-subnet-group"
  subnet_ids   = values(aws_subnet.private)[*].id
  tags         = { Name = "rds-subnet-group" }
}

resource "aws_db_instance" "primary" {
  identifier           = var.primary_rds_identifier
  engine               = "postgres"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  db_name              = var.db_name
  username             = var.db_user
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible  = false
  skip_final_snapshot  = true
}

resource "aws_db_instance" "replica" {
  identifier           = var.replica_rds_identifier
  engine               = aws_db_instance.primary.engine
  instance_class       = "db.t3.micro"
  replicate_source_db  = aws_db_instance.primary.arn
  db_subnet_group_name = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible  = false
  skip_final_snapshot  = true
}

# ------------------------
# EKS Cluster + Node Group
# ------------------------
resource "aws_eks_cluster" "cluster" {
  name       = var.eks_cluster_name
  role_arn   = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids           = concat(values(aws_subnet.private)[*].id, values(aws_subnet.public)[*].id)
    endpoint_public_access = true
  }

  version = var.eks_version
}

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
}

# ------------------------
# Providers
# ------------------------

provider "kubernetes" {
  host                   = aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.cluster.name]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.cluster.name]
    }
  }
}

# ------------------------
# Standalone EC2 Instance
# ------------------------
resource "aws_instance" "link_ec2" {
  ami           = "ami-053b04d1a523a968a" # Ubuntu 20.04 LTS for us-east-1. Change if you are using a different region.
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public[0].id
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.link_ec2.id,
    aws_security_group.eks_nodes.id # To allow it to talk to EKS nodes
  ]
  iam_instance_profile = aws_iam_instance_profile.link_ec2_profile.name
  key_name             = "your-key-name" # Change to your actual key pair name

  user_data = <<-EOF
              #!/bin/bash
              # Install AWS CLI and unzip
              sudo apt-get update -y
              sudo apt-get install -y awscli unzip

              # Create directory for the files
              mkdir -p /home/ubuntu
              cd /home/ubuntu

              # Download files from S3
              aws s3 cp s3://your-s3-bucket-name/file1.txt .
              aws s3 cp s3://your-s3-bucket-name/link-ec2-tool.sh .

              # Make the script executable and run it
              chmod +x link-ec2-tool.sh
              ./link-ec2-tool.sh
              EOF

  tags = {
    Name = "link-project-ec2"
  }
}


# ------------------------
# Install ALB Ingress Controller via Helm
# ------------------------

resource "helm_release" "alb_controller" {
  depends_on = [
    aws_eks_cluster.cluster,
    aws_eks_node_group.managed_nodes
  ] 
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.cluster.name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

# ------------------------
# Random IDs
# ------------------------
resource "random_id" "ekscid" { byte_length = 4 }
resource "random_id" "eksnid" { byte_length = 4 }

# ------------------------
# Outputs
# ------------------------
output "primary_db_endpoint" {
  value = aws_db_instance.primary.address
}
output "replica_db_endpoint" {
  value = aws_db_instance.replica.address
}
output "eks_cluster_name" {
  value = aws_eks_cluster.cluster.name
}

output "ec2_public_ip" {
  value = aws_instance.link_ec2.public_ip
}
