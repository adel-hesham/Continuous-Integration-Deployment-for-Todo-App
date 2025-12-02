resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr_block

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main"
  }
}

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

    tags = {
    Name = "igw"
  }
}

resource "aws_subnet" "public_AZ1" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/19"
  availability_zone       = local.AZ1
  map_public_ip_on_launch = true

  tags = {
    "Name"                                                 = "public-${local.AZ1}"
    "kubernetes.io/role/elb"                               = "1"
    "kubernetes.io/cluster/${local.eks_name}" = "owned"
  }

}

resource "aws_subnet" "public_AZ2" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.32.0/19"
  availability_zone       = local.AZ2
  map_public_ip_on_launch = true

  tags = {
    "Name"                                                 = "public-${local.AZ2}"
    "kubernetes.io/role/elb"                               = "1"
    "kubernetes.io/cluster/${local.eks_name}" = "owned"
  }

}


resource "aws_subnet" "private_AZ1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.64.0/19"
  availability_zone = local.AZ1
  tags = {
    "Name"                                                 = "private-${local.AZ1}"
    "kubernetes.io/role/internal-elb"                      = "1"
    "kubernetes.io/cluster/${local.eks_name}" = "owned"
  }
}


resource "aws_subnet" "private_AZ2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.96.0/19"
  availability_zone = local.AZ2
  tags = {
    "Name"                                                 = "private-${local.AZ2}"
    "kubernetes.io/role/internal-elb"                      = "1"
    "kubernetes.io/cluster/${local.eks_name}" = "owned"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_AZ1.id

  tags = {
    Name = "public NAT"
  }

  depends_on = [aws_internet_gateway.igw]
}
resource "aws_eip" "eip" {
  
  domain = "vpc"

    tags = {
    Name = "nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "public_route"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_AZ1" {
  subnet_id      = aws_subnet.public_AZ1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_AZ2" {
  subnet_id      = aws_subnet.public_AZ2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "private_route"
  }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
}

resource "aws_route_table_association" "private_AZ1" {
  subnet_id      = aws_subnet.private_AZ1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_AZ2" {
  subnet_id      = aws_subnet.private_AZ2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_key_pair" "my_key" {
  key_name   = "elnimr"
  public_key = file("/home/adel/elnimr.pub")
}

###########EKS###############


resource "aws_iam_role" "eks" {
  name = "${local.eks_name}-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_cluster" "eks" {
  name     = "${local.eks_name}"
  version  = local.eks_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true

    subnet_ids = [

      aws_subnet.private_AZ1.id,
      aws_subnet.private_AZ2.id
    ]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks]
}

######################  WORKER-NODES  #############


resource "aws_iam_role" "nodes" {
  name = "${local.eks_name}-eks-nodes"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
POLICY
}

# This policy now includes AssumeRoleForPodIdentity for the Pod Identity Agent
resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.eks.name
  version         = local.eks_version
  node_group_name = "general"
  node_role_arn   = aws_iam_role.nodes.arn

  subnet_ids = [
    aws_subnet.private_AZ1.id,
    aws_subnet.private_AZ2.id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = ["c7i-flex.large"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
resource "null_resource" "import_k8s_lb_sg" {
  provisioner "local-exec" {
    command = <<EOT
# Detect the K8s LB security group
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:kubernetes.io/cluster/solar-system-application,Values=owned" \
            "Name=description,Values='Security group for Kubernetes ELB*'" \
  --query 'SecurityGroups[0].GroupId' --output text)

# Import it into Terraform state if exists
if [ "$SG_ID" != "None" ]; then
  terraform import aws_security_group.k8s_lb_sg $SG_ID
fi
EOT
    interpreter = ["/bin/bash", "-c"]
  }

  # Run only on destroy
  triggers = {
    always_run = "${timestamp()}"
  }
}
