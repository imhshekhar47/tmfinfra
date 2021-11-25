variable "enable_public_access" {
  description = "Enable public access"
  type = bool

  default = false
}

variable "vpc_id" {
  description = "VPC Id"
  type = string
}

variable "db_subnet_ids" {
  description = "Subnet Ids of for theDB subnet group"
  type        = list(string)
}

variable "availability_zone" {
  description = "Availability zone for RDS"
  type        = string
}

variable "db_name" {
  description = "DB name"
  type        = string
}

variable "db_username" {
  description = "RDS Admin username"
  type        = string
  default     = "admin"
}


variable "db_password" {
  description = "RDS Admin password"
  sensitive   = true
  type        = string
}