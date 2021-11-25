data "aws_caller_identity" "owner" {}

# Create subnet for EKS
resource "aws_subnet" "eks_subnet" {
  count = length(var.eks_subnets)

  vpc_id            = var.vpc_id
  cidr_block        = element(var.eks_subnets.*.cidr_block, count.index)
  availability_zone = element(var.eks_subnets.*.availability_zone, count.index)

  map_public_ip_on_launch = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared",
    "kubernetes.io/role/elb"                    = 1
    "Name"                                      = element(var.eks_subnets.*.name, count.index)
  }
}

# create eks routing table
resource "aws_route_table" "eks_route_tbl" {
  vpc_id = var.vpc_id

  tags = {
    Name = "eks-route-table"
  }
}

# Add public route to internet gatewy
resource "aws_route" "eks_route" {
  route_table_id         = aws_route_table.eks_route_tbl.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

# Add public subnet to public route
resource "aws_route_table_association" "eks_subnet_rt_associattion" {
  count = length(var.eks_subnets)

  subnet_id      = element(aws_subnet.eks_subnet.*.id, count.index)
  route_table_id = aws_route_table.eks_route_tbl.id
}

#------------------------------------------------
# Setup EKS Cluster
#------------------------------------------------

# Define EKS Cluster IAM role
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    node = "cluster"
  }
}

# Add AmazonEKSClusterPolicy to eks-cluster-role
resource "aws_iam_role_policy_attachment" "cluster_iam_eksclusterpolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Add AmazonEKSServicePolicy to eks-cluster-role
resource "aws_iam_role_policy_attachment" "cluster_iam_eksservicepolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Create EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  depends_on = [
    aws_iam_role_policy_attachment.cluster_iam_eksclusterpolicy,
    aws_iam_role_policy_attachment.cluster_iam_eksservicepolicy
  ]

  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.eks_subnet.*.id
  }

  tags = {
    node = "cluster"
  }
}


#------------------------------------------------
# Setup EKS NodeGroup
#------------------------------------------------

# EKS Worker node
resource "aws_iam_role" "eks_worker_role" {
  name = "eks-worker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    node = "worker"
  }
}

# Add AmazonEKSWorkerNodePolicy policy to worker-role
resource "aws_iam_role_policy_attachment" "worker_iam_nodepolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_worker_role.name
}

# Add AmazonEKS_CNI_Policy policy to worker-role
resource "aws_iam_role_policy_attachment" "worker_iam_cnipolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_worker_role.name
}

# Add AmazonEC2ContainerRegistryReadOnly policy to worker-role
resource "aws_iam_role_policy_attachment" "worker_iam_registrypolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_worker_role.name
}

# TODO
resource "aws_iam_instance_profile" "worker_node_profile" {
  name = "worker-node"
  role = aws_iam_role.eks_worker_role.name
}

resource "aws_eks_node_group" "eks_nodes" {
  depends_on = [
    aws_iam_role_policy_attachment.worker_iam_nodepolicy,
    aws_iam_role_policy_attachment.worker_iam_cnipolicy,
    aws_iam_role_policy_attachment.worker_iam_registrypolicy,
  ]

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = var.nodegroup_name
  node_role_arn   = aws_iam_role.eks_worker_role.arn
  subnet_ids      = aws_subnet.eks_subnet.*.id
  instance_types  = ["t2.small"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }
}

data "aws_eks_cluster" "eks_cluster" {
  name = aws_eks_cluster.eks_cluster.id
}

data "aws_eks_cluster_auth" "eks_cluster_auth" {
  name = aws_eks_cluster.eks_cluster.id
}

#------------------------------------------------
# Create & Associate IAM OIDC Provider for our EKS Cluster
#------------------------------------------------

data "tls_certificate" "oidc_issuer" {
  url = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
}

# ### OIDC config
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_issuer.certificates.0.sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
}

#------------------------------------------------
# Create ALB Ingress Controller
#------------------------------------------------

# Create IAM role for ingresscontroller
resource "aws_iam_role" "eks_albingresscontroller_role" {
  name = "AmazonEKSLoadBalancerControllerRole"

  description = "Permissions required by the Kubernetes AWS ALB Ingress controller to do it's job."

  force_detach_policies = true

  assume_role_policy = <<ROLE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.owner.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:kube-system:alb-ingress-controller"
        }
      }
    }
  ]
}
ROLE

  tags = {
    node = "cluster"
  }
}

# Create IAM Policy
resource "aws_iam_policy" "eks_albcontrollerpolicy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/iam_policy.json")

  tags = {
    Name = "AWSLoadBalancerControllerIAMPolicy"
  }
}

# Attach policy to role for ingress controller
resource "aws_iam_role_policy_attachment" "eks_albingresscontrolleraiampolicy" {
  role       = aws_iam_role.eks_albingresscontroller_role.name
  policy_arn = aws_iam_policy.eks_albcontrollerpolicy.arn
}

