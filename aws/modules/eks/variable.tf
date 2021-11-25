variable "vpc_id" {
  description = "VPC Id"
  type        = string
}

variable "internet_gateway_id" {
  description = "Internet gateway id"
  type        = string
}

variable "eks_subnets" {
  description = "Subnets for eks"
  type = list(object({
    name              = string
    availability_zone = string
    cidr_block        = string
  }))
}

variable "cluster_name" {
  description = "Name for the EKS cluster"
  type        = string
}

variable "nodegroup_name" {
  description = "Name for the EKS nodegroup"
  type        = string
}