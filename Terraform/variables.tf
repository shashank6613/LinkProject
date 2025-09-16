# AWS Region
variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "us-west-2"
}

variable "env" {
  default = "dev"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for the private subnets."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  description = "A list of availability zones to use."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

# EKS Cluster Configuration
variable "eks_cluster_name" {
  description = "The name for the EKS cluster."
  type        = string
  default     = "link-clus"
}

variable "eks_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.28"
}

# EKS Node Group Configuration
variable "node_group_desired" {
  description = "The desired number of EKS worker nodes."
  type        = number
  default     = 1
}

variable "node_group_min" {
  description = "The minimum number of EKS worker nodes."
  type        = number
  default     = 1
}

variable "node_group_max" {
  description = "The maximum number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "node_instance_type" {
  description = "The instance type for the EKS worker nodes."
  type        = string
  default     = "t3.medium"
}

# RDS Database Configuration
variable "primary_rds_identifier" {
  description = "The identifier for the primary RDS instance."
  type        = string
  default     = "link-project-primary-db"
}

variable "replica_rds_identifier" {
  description = "The identifier for the replica RDS instance."
  type        = string
  default     = "link-project-replica-db"
}

variable "db_name" {
  description = "The name of the database."
  type        = string
  default     = "primarydb"
}

variable "db_user" {
  description = "The master username for the database."
  type        = string
  default     = "shank"
}

variable "db_password" {
  description = "The master password for the database. IMPORTANT: Use a more secure method like AWS Secrets Manager for production."
  type        = string
  default     = "admin12345"
}

# EC2 Instance Configuration
variable "ec2_ami_id" {
  description = "The AMI ID for the EC2 instance."
  type        = string
  default     = "ami-065778886ef8ec7c8" # Ubuntu 22.04 LTS in us-west-2
}

variable "ec2_instance_type" {
  description = "The instance type for the EC2 instance."
  type        = string
  default     = "t3.medium"
}

variable "ec2_key_name" {
  description = "The name of the EC2 key pair to use."
  type        = string
  default     = "linked"
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket to download files from."
  type        = string
  default     = "twentyseventhbucket"
}

variable "s3_file1_name" {
  description = "The name of the first file to download from S3."
  type        = string
  default     = "Link-Project/link-tool-check.sh"
}

variable "s3_file2_name" {
  description = "The name of the second file to download from S3."
  type        = string
  default     = "Link-Project/link-ec2-tool.sh"
}
