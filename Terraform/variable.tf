# -------------------------
# AWS Region
# -------------------------
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

# -------------------------
# VPC and Subnets
# -------------------------
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to spread subnets"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

# -------------------------
# EKS Config
# -------------------------
variable "eks_cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "linkproj-eks"
}

variable "eks_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "Instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_group_desired" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_min" {
  description = "Minimum worker nodes"
  type        = number
  default     = 1
}

variable "node_group_max" {
  description = "Maximum worker nodes"
  type        = number
  default     = 3
}

# -------------------------
# RDS Config
# -------------------------
variable "primary_rds_identifier" {
  description = "Primary RDS instance identifier"
  type        = string
  default     = "myprimarypgdb"
}

variable "replica_rds_identifier" {
  description = "Replica RDS instance identifier"
  type        = string
  default     = "myreplicapgdb"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "primarydb"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "shank"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "admin12345"
  sensitive   = true
}
