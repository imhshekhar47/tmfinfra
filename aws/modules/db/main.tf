resource "aws_security_group" "rds_sg" {
  vpc_id      = var.vpc_id
  name        = "rds-sg"
  description = "Security group for RDS"

  ingress {
    description = "Allow mysql connectivity to ALL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    description = "Allow all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
    Name = "rds-sg"
  }

}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    type = "db-subnet-group"
  }
}

resource "aws_db_instance" "app_db" {
  identifier_prefix    = "${var.db_name}-"
  availability_zone    = var.availability_zone
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  allocated_storage    = 5
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name = "tmf632"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  publicly_accessible  = var.enable_public_access
  vpc_security_group_ids = [ aws_security_group.rds_sg.id ]

  tags = {
    Name = "rds-${var.db_name}"
    type = "mysql"
  }
}
