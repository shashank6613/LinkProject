# ------------------------
# EKS Cluster & Node Group
# ------------------------
output "eks_cluster_name" {
  value = aws_eks_cluster.cluster.name
}
output "eks_cluster_arn" {
  value = aws_eks_cluster.cluster.arn
}
output "eks_node_group_name" {
  value = aws_eks_node_group.managed_nodes.node_group_name
}
output "eks_node_group_arn" {
  value = aws_eks_node_group.managed_nodes.arn
}

# ------------------------
# IAM Roles
# ------------------------
output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}
output "eks_node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}
output "link_ec2_role_arn" {
  value = aws_iam_role.link_ec2_role.arn
}
output "backend_sa_role_arn" {
  value = aws_iam_role.backend_sa_role.arn
}

# ------------------------
# IAM Instance Profile
# ------------------------
output "link_ec2_instance_profile_arn" {
  value = aws_iam_instance_profile.link_ec2_profile.arn
}

# ------------------------
# IAM Policies
# ------------------------
output "link_ec2_policy_arn" {
  value = aws_iam_policy.link_ec2_policy.arn
}
output "backend_secrets_policy_name" {
  value = aws_iam_role_policy.backend_secrets.name
}

# ------------------------
# VPC & Subnets
# ------------------------
output "vpc_id" {
  value = aws_vpc.this.id
}
output "public_subnet_0_id" {
  value = aws_subnet.public["0"].id
}
output "public_subnet_1_id" {
  value = aws_subnet.public["1"].id
}
output "private_subnet_0_id" {
  value = aws_subnet.private["0"].id
}
output "private_subnet_1_id" {
  value = aws_subnet.private["1"].id
}

# ------------------------
# Internet Gateway & NAT
# ------------------------
output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}
output "nat_gateway_id" {
  value = aws_nat_gateway.nat.id
}
output "nat_eip_id" {
  value = aws_eip.nat.id
}

# ------------------------
# Route Tables & Associations
# ------------------------
output "private_route_table_id" {
  value = aws_route_table.private.id
}
output "public_route_table_id" {
  value = aws_route_table.public.id
}
output "private_assoc_0" {
  value = aws_route_table_association.private_assoc["0"].id
}
output "private_assoc_1" {
  value = aws_route_table_association.private_assoc["1"].id
}
output "public_assoc_0" {
  value = aws_route_table_association.public_assoc["0"].id
}
output "public_assoc_1" {
  value = aws_route_table_association.public_assoc["1"].id
}

# ------------------------
# Security Groups
# ------------------------
output "eks_nodes_sg_id" {
  value = aws_security_group.eks_nodes.id
}
output "link_ec2_sg_id" {
  value = aws_security_group.link_ec2.id
}
output "rds_sg_id" {
  value = aws_security_group.rds_sg.id
}

# ------------------------
# EC2 Instance
# ------------------------
output "ec2_instance_id" {
  value = aws_instance.link_ec2.id
}
output "ec2_instance_public_ip" {
  value = aws_instance.link_ec2.public_ip
}

# ------------------------
# RDS Subnet Group & DB Instances
# ------------------------
output "rds_subnet_group_id" {
  value = aws_db_subnet_group.rds_subnets.id
}
output "primary_rds_endpoint" {
  value = aws_db_instance.primary.endpoint
}
output "replica_rds_endpoint" {
  value = aws_db_instance.replica.endpoint
}

# ------------------------
# Helm Releases
# ------------------------
output "alb_controller_name" {
  value = helm_release.alb_controller.name
}

# ------------------------
# OIDC Provider
# ------------------------
output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

# ------------------------
# AlB Controller
# ------------------------

# IAM role created for ALB Controller
output "alb_controller_iam_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

# IAM policy created for ALB Controller
output "alb_controller_iam_policy_arn" {
  description = "IAM policy ARN attached to the ALB Controller role"
  value       = aws_iam_policy.alb_controller_policy.arn
}

# Kubernetes service account created
output "alb_controller_service_account" {
  description = "Service account name for AWS Load Balancer Controller"
  value       = kubernetes_service_account.alb_controller.metadata[0].name
}

# Helm release status
output "alb_controller_helm_status" {
  description = "Status of the Helm release for AWS Load Balancer Controller"
  value       = helm_release.alb_controller.status
}

# Helm chart version for ALB Controller
output "alb_controller_helm_chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart installed"
  value       = helm_release.alb_controller.version
}


# ------------------------
# Random IDs
# ------------------------
output "random_id_ekscid" {
  value = random_id.ekscid.hex
}
output "random_id_eksnid" {
  value = random_id.eksnid.hex
}
