#------------------------------------------------
# Setup vpc
#------------------------------------------------

data "aws_availability_zones" "current_azs" {
  state = "available"
}

locals {
  selected_azs = slice(data.aws_availability_zones.current_azs.names, 0, 2)
}


module "vpc" {
  source = "./modules/vpc"

  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  pub_subnets = [
    {
      name              = format("subnet-ui-%s", substr(local.selected_azs[0], -2, -1))
      availability_zone = local.selected_azs[0]
      cidr_block        = cidrsubnet("10.0.0.0/16", 8, 0)
    },
    {
      name              = format("subnet-ui-%s", substr(local.selected_azs[1], -2, -1))
      availability_zone = local.selected_azs[1]
      cidr_block        = cidrsubnet("10.0.0.0/16", 8, 1)
    }
  ]

  enable_flow_logs = false
  enable_alb       = false
}


variable "db_password" {
  sensitive = true
  type      = string
}

module "db" {
  source = "./modules/db"

  vpc_id            = module.vpc.o_vpc.id
  db_subnet_ids     = module.vpc.o_pub_subnets.*.id
  availability_zone = module.vpc.o_pub_subnets.0.availability_zone
  db_name           = "tmf632"
  db_username       = "admin"
  db_password       = var.db_password

}

module "eks" {
  source = "./modules/eks"

  vpc_id              = module.vpc.o_vpc.id
  internet_gateway_id = module.vpc.o_igw_id
  eks_subnets = [
    {
      name              = format("subnet-eks-%s", substr(local.selected_azs[0], -2, -1))
      availability_zone = local.selected_azs[0]
      cidr_block        = cidrsubnet("10.0.0.0/16", 8, 2)
    },
    {
      name              = format("subnet-eks-%s", substr(local.selected_azs[1], -2, -1))
      availability_zone = local.selected_azs[1]
      cidr_block        = cidrsubnet("10.0.0.0/16", 8, 3)
    }
  ]

  cluster_name   = "eks-cluster"
  nodegroup_name = "eks-node"
}


# module "tmf632" {
#   depends_on = [ 
#       module.vpc, 
#   ]
#   source = "./modules/tmf632"

#   vpc_id       = module.vpc.o_vpc.id
#   availability_zones = local.selected_azs 
#   #http_for_sgs = flatten(module.vpc.o_tmf_albs.*.security_groups)
#   alb_arn = module.vpc.o_alb.arn
#   #alb_subnets  = flatten(module.vpc.o_tmf_albs.*.subnets)
# }