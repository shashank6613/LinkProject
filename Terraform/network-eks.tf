# ------------------------
# VPC + Subnets + IGW + NAT
# ------------------------
resource "aws_vpc" "this" {
  cidr_block            = var.vpc_cidr
  enable_dns_support    = true
  enable_dns_hostnames  = true
  tags = { Name = "link-project-vpc" }
}

resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[each.key % length(var.availability_zones)]
  map_public_ip_on_launch = true
  tags = { 
    Name = "public-subnet-${each.key}" 
    "kubernetes.io/role/elb"          = "1"
    "kubernetes.io/cluster/link-clus" = "shared"
  }
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[each.key % length(var.availability_zones)]
  map_public_ip_on_launch = false
  tags = { 
    Name = "private-subnet-${each.key}" 
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/link-clus" = "shared"
  }
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
resource "aws_security_group" "eks_nodes" {
  name        = "eks-nodes-sg"
  vpc_id      = aws_vpc.this.id
  description = "EKS worker nodes SG"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "eks-nodes-sg" }
}

resource "aws_security_group" "link_ec2" {
  name        = "link-ec2-sg"
  vpc_id      = aws_vpc.this.id
  description = "SG for EC2 instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow Postgres access from EKS nodes + EC2"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id, aws_security_group.link_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg" }
}

# ------------------------
# IAM for EKS
# ------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-role-${random_id.ekscid.hex}"
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

resource "aws_iam_role" "eks_node_role" {
  name               = "eks-node-role-${random_id.eksnid.hex}"
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

# ------------------------
# IAM for EC2
# ------------------------
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
        Action   = [
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/Link-Project/*"
      },
      {
        Action   = "s3:ListBucket"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.s3_bucket_name}"
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
      },
      {
        Effect   = "Allow"
        Action   = [
          "iam:GetInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          # ECR permissions
          "ecr:DescribeRepositories",
          "ecr:CreateRepository",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
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

# ------------------------
# EKS Cluster + Node Group
# ------------------------
resource "aws_eks_cluster" "cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_A
  ]

  vpc_config {
    subnet_ids              = concat(values(aws_subnet.private)[*].id, values(aws_subnet.public)[*].id)
    endpoint_public_access  = true
  }

  version = var.eks_version
}

resource "aws_eks_node_group" "managed_nodes" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.eks_cluster_name}-ng"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = values(aws_subnet.private)[*].id
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_A,
    aws_iam_role_policy_attachment.eks_cni
  ]

  scaling_config {
    desired_size = var.node_group_desired
    min_size     = var.node_group_min
    max_size     = var.node_group_max
  }

  instance_types = [var.node_instance_type]
  ami_type       = "AL2_x86_64"
}


# ------------------------
# IRSA for Backend Pods (NEW)
# ------------------------

data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.cluster.name
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

# Trust policy for backend service account
data "aws_iam_policy_document" "backend_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:backend-sa"]
    }
  }
}

# IAM Role for backend pods
resource "aws_iam_role" "backend_sa_role" {
  name               = "eks-backend-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.backend_assume_role.json
}

# Policy for accessing the RDS secret
resource "aws_iam_role_policy" "backend_secrets" {
  name = "backend-secrets-policy"
  role = aws_iam_role.backend_sa_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:us-west-2:799344209838:secret:my-rds-secret*"
      }
    ]
  })
}


# ------------------------
# Random IDs
# ------------------------
resource "random_id" "ekscid" { byte_length = 4 }
resource "random_id" "eksnid" { byte_length = 4 }

