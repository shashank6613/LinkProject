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
              chmod +x ${var.s3_file1_name}
              ./$(basename ${var.s3_file2_name})
              EOF

  tags = { Name = "link-project-ec2" }
}

# --------------------------------------------
# IAM Role for AWS Load Balancer Controller
# --------------------------------------------
resource "aws_iam_role" "alb_controller" {
  name = "${aws_eks_cluster.cluster.name}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated   = local.eks_oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# --------------------------------------------
# Fetch Official AWS LB Controller IAM Policy
# --------------------------------------------
data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller_policy" {
  name        = "${aws_eks_cluster.cluster.name}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.http.alb_controller_policy.response_body
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}

# --------------------------------------------
# ServiceAccount for ALB Controller
# --------------------------------------------
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }
}

# --------------------------------------------
# Helm Release for AWS Load Balancer Controller
# --------------------------------------------
resource "helm_release" "alb_controller" {
  depends_on = [
    aws_eks_cluster.cluster,
    aws_eks_node_group.managed_nodes,
    kubernetes_service_account.alb_controller
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
    value = kubernetes_service_account.alb_controller.metadata[0].name
  }
}
