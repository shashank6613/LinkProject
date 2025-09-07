variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs (2)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs (2)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use (length should match subnet counts)"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "link-cluster"
}

variable "node_group_desired" { default = 1 }
variable "node_group_min"     { default = 1 }
variable "node_group_max"     { default = 2 }

variable "node_instance_type" {
  default = "t3.medium"
}

variable "master_ec2_instance_type" {
  default = "t2.medium"
}

variable "ssh_key_name" {
  description = "Existing EC2 Key pair name to attach to EC2 for SSH (must exist in region)"
  type        = string
  default     = "linked"
}

variable "master_ec2_ami" {
  description = "AMI for the master EC2 (replace with region-specific Ubuntu AMI)"
  type        = string
  default     = "ami-REPLACE_ME"
}

variable "eks_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.27"
}

variable "db_name"    { default = "primarydb" }
variable "db_user"    { default = "pgadmin" }
variable "db_password" {
  description = "RDS master password"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "primary_rds_identifier" { default = "MyPrimaryPGDB" }
variable "replica_rds_identifier" { default = "MyReplicaPGDB" }
