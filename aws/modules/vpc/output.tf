output "o_vpc" {
  value = aws_vpc.main_vpc
}

output "o_igw_id" {
  value = aws_internet_gateway.main_vpc_gw.id
}

output "o_pub_subnets" {
  value = aws_subnet.pub_subnets
}

output "o_alb" {
  value = var.enable_alb ? aws_lb.pub_alb[0] : null
}
