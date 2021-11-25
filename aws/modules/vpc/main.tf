#------------------------------------------------
# Setup vpc 
#------------------------------------------------

# Create main vpc 
resource "aws_vpc" "main_vpc" {
  cidr_block = var.cidr_block

  enable_dns_support = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = "main-vpc"
  }
}

# Create internet gateway for the vpc
resource "aws_internet_gateway" "main_vpc_gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-vpc-gw"
  }
}

# Create public subnets
resource "aws_subnet" "pub_subnets" {
  count = length(var.pub_subnets)

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = element(var.pub_subnets.*.cidr_block, count.index)
  availability_zone = element(var.pub_subnets.*.availability_zone, count.index)

  tags = {
    Name = element(var.pub_subnets.*.name, count.index)
  }
}

# Define public routing table
resource "aws_route_table" "pub_route_tbl" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "pub-route-table"
  }
}

# Add public route to internet gatewy
resource "aws_route" "pub_route" {
  route_table_id         = aws_route_table.pub_route_tbl.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_vpc_gw.id
}

# Add public subnet to public route
resource "aws_route_table_association" "pub_subnet_rt_associattion" {
  count = length(var.pub_subnets)

  subnet_id      = element(aws_subnet.pub_subnets.*.id, count.index)
  route_table_id = aws_route_table.pub_route_tbl.id
}

#------------------------------------------------
# Setup vpc logging
#------------------------------------------------

# Define IAM role for creating CloudWatch logs
resource "aws_iam_role" "vpc_logger_role" {
  name        = "vpc-logger-role"
  description = "Can write vpc logs"

  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "vpc-flow-logs.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "vpc-logger-role"
  }
}

# Add CloudWatch access polic for IAM role 
resource "aws_iam_role_policy" "cw_access_policy" {
  name = "tmf-cloudwatch-access-policy"
  role = aws_iam_role.vpc_logger_role.id

  policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# Create CloudWatch Log group for vpc logs
resource "aws_cloudwatch_log_group" "vpc_log_group" {
  name = "tmf-vpc-log-group"

  tags = {
    Name = "tmf-vpc-log-group"
  }
}

# Create vpc flow log
resource "aws_flow_log" "vpc_flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.main_vpc.id
  iam_role_arn    = aws_iam_role.vpc_logger_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_log_group.arn
  traffic_type    = "ALL"
}

#------------------------------------------------
# Setup Application Load Balancer
#------------------------------------------------

# Define SG for load balancer
resource "aws_security_group" "pub_alb_sg" {
  name        = "pub-alb-sg"
  description = "Security group for public ALB"

  vpc_id = aws_vpc.main_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow public HTTP traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pub-alb-sg"
  }
}

# Define ALB
resource "aws_lb" "pub_alb" {

  count = var.enable_alb ? 1 : 0

  name               = "pub-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.pub_alb_sg.id
  ]

  subnets = aws_subnet.pub_subnets.*.id

  tags = {
    Name = "pub-alb"
  }
}