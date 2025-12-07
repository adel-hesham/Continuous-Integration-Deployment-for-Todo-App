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
  node_group_name = "general"
  node_role_arn   = aws_iam_role.nodes.arn

  subnet_ids = [
    aws_subnet.private_AZ1.id,
    aws_subnet.private_AZ2.id
  ]

  capacity_type  = "ON_DEMAND"

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

    launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
    }
  
}

# 1. Get the latest AMI ID dynamically
data "aws_ssm_parameter" "eks_ami" {
  # New path for Amazon Linux 2023
  name = "/aws/service/eks/optimized-ami/${local.eks_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "eks-node-"
  image_id      = data.aws_ssm_parameter.eks_ami.value
  instance_type = "t3.medium"

  # AL2023 requires explicit cluster details in User Data if you override it
  user_data = base64encode(<<-EOT
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: application/node.eks.aws
Content-Transfer-Encoding: 8bit

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${aws_eks_cluster.eks.name}
    apiServerEndpoint: ${aws_eks_cluster.eks.endpoint}
    certificateAuthority: ${aws_eks_cluster.eks.certificate_authority[0].data}
    cidr: ${aws_eks_cluster.eks.kubernetes_network_config[0].service_ipv4_cidr}

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -ex

# 1. Define Nexus IP/Port
NEXUS_HOST="${local.nexus_private_ip}"
NEXUS_PORT="${local.http_port}"

# 2. Create the hosts.toml for containerd (The AL2023 way)
mkdir -p "/etc/containerd/certs.d/${local.nexus_private_ip}:${local.http_port}"

cat <<EOF > "/etc/containerd/certs.d/${local.nexus_private_ip}:${local.http_port}/hosts.toml"
server = "http://${local.nexus_private_ip}:${local.http_port}"

[host."http://${local.nexus_private_ip}:${local.http_port}"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF

# 3. Restart containerd to apply changes
systemctl restart containerd

--==MYBOUNDARY==--
  EOT
  )
}