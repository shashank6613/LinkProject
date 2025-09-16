# ------------------------
# RDS (Primary + Replica)
# ------------------------
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = values(aws_subnet.private)[*].id
  tags       = { Name = "rds-subnet-group" }
}

resource "aws_db_instance" "primary" {
  identifier              = var.primary_rds_identifier
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = var.db_name
  username                = var.db_user
  password                = var.db_password
  backup_retention_period = 7
  depends_on = [aws_security_group.rds_sg]
  db_subnet_group_name    = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
}

resource "aws_db_instance" "replica" {
  identifier              = var.replica_rds_identifier
  engine                  = aws_db_instance.primary.engine
  instance_class          = "db.t3.micro"
  depends_on = [aws_db_instance.primary]
  replicate_source_db     = aws_db_instance.primary.arn
  db_subnet_group_name    = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
}

# ------------------------
# EC2 Instance
# ------------------------
resource "aws_instance" "link_ec2" {
  ami                         = var.ec2_ami_id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.link_ec2.id, aws_security_group.eks_nodes.id]
  depends_on = [aws_iam_instance_profile.link_ec2_profile]
  iam_instance_profile        = aws_iam_instance_profile.link_ec2_profile.name
  key_name                    = var.ec2_key_name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y awscli unzip
              mkdir -p /home/ubuntu
              cd /home/ubuntu
              aws s3 cp s3://${var.s3_bucket_name}/Link-Project/${var.s3_file1_name} .
              aws s3 cp s3://${var.s3_bucket_name}/Link-Project/${var.s3_file2_name} .
              chmod +x ${var.s3_file2_name}
              ./$(basename ${var.s3_file2_name})
              EOF

  tags = { Name = "link-project-ec2" }
}

# ------------------------
# ALB Ingress Controller via Helm
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
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

#------------------------
# Updating ConfigMap
#------------------------
# Data source to get the IAM role created for the EC2 instance
data "aws_iam_role" "link_ec2" {
  name = aws_iam_role.link_ec2.name
}

# Data source to retrieve the EKS cluster's identity
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.my_eks_cluster.name
}

# The aws-auth ConfigMap to map the EC2 IAM role to a Kubernetes group
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<-EOT
      - rolearn: ${data.aws_iam_role.link_ec2.arn}
        username: ec2-admin
        groups:
          - system:masters
    EOT
  }
  depends_on = [aws_eks_cluster.my_eks_cluster, aws_eks_node_group.my_eks_node_group]
}



# ------------------------
# Outputs
# ------------------------
output "env_file_content" {
  description = "Content for the .env file with database credentials and hosts."
  value = <<-EOT
DB_HOST=${aws_db_instance.primary.address}
READ_REPLICA_HOST=${aws_db_instance.replica.address}
DB_USER=${var.db_user}
DB_PASSWORD=${var.db_password}
DB_NAME=${var.db_name}
EOT
}

output "eks_cluster_name" {
  value = aws_eks_cluster.cluster.name
}

output "ec2_public_ip" {
  value = aws_instance.link_ec2.public_ip
}

