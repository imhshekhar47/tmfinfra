variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "enable_dns_support" {
  type = bool
  description = "Emabel DNS Support"
  default = false
}

variable "enable_dns_hostnames" {
  type = bool
  description = "Enable DNS Hostnames"
  default = false
}

variable "pub_subnets" {
  description = "Subnet details"

  type = list(object({
    name              = string
    availability_zone = string
    cidr_block        = string
  }))
}

variable "enable_flow_logs" {
  description = "Flag to enable vpc flow logs"
  type        = bool
}

variable "enable_alb" {
  description = "Flag to enable ALB"
  type        = bool
}

# variable "vpc_details" {
#     type = object({
#         cidr_block = string
#         ui_subnets = list(string)

#         enable_flow_logs = bool
#     })
# }