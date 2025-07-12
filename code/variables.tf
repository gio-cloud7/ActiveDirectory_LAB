variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "ad_domain_name" {
  description = "Active Directory domain name"
  default     = "example.local"
}

variable "ad_domain_netbios_name" {
  description = "Active Directory NetBIOS name"
  default     = "EXAMPLE"
}

variable "instance_type_dc" {
  description = "Instance type for Domain Controllers"
  default     = "t3.medium"
}

variable "instance_type_app" {
  description = "Instance type for Application Server"
  default     = "t3.medium"
}

variable "instance_type_sql" {
  description = "Instance type for SQL Server"
  default     = "t3.large"
}

variable "instance_type_workstation" {
  description = "Instance type for Workstations"
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  default     = "your-key-pair-name"
}

variable "admin_password" {
  description = "Password for domain administrator"
  type        = string
  sensitive   = true
  default     = "YourAdminPassword123" # Change this in production!
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}
