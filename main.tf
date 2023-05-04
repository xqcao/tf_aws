provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_iam_user" "eks_user" {
  name = var.eks_user
}

resource "aws_iam_role" "eks_role" {
  name               = "eks_role"
  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "eks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  EOF
}
resource "aws_iam_user" "ec2_user" {
  name = var.ec2_user
}
resource "aws_iam_role" "ec2_role" {
  name               = "eks_role"
  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  EOF
}
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_eks_cni_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_role_policy_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_user_policy_attachment" "eks_user_policy_attachment" {
  user       = aws_iam_user.eks_user.name
  policy_arn = aws_iam_role.eks_role.arn
}




resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  instance_tenancy                 = "default"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "eks_node_group_public_subnet_1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.0.0/18"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name                        = "eks_public_subnet_us_east_1a"
    "kubernetes.io/cluster/eks" = "shared"
    "kubernetes.io/role/elb"    = 1
  }
}

resource "aws_subnet" "eks_node_group_public_subnet_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.64.0/18"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name                        = "eks_public_subnet_us_east_1b"
    "kubernetes.io/cluster/eks" = "shared"
    "kubernetes.io/role/elb"    = 1
  }
}

resource "aws_subnet" "eks_node_group_private_subnet_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.128.0/18"
  availability_zone = "us-east-1a"
  tags = {
    Name                              = "eks_private_subnet_us_east_1a"
    "kubernetes.io/cluster/eks"       = "shared"
    "kubernetes.io/role/internat-elb" = 1
  }
}
resource "aws_subnet" "eks_node_group_private_subnet_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.192.0/18"
  availability_zone = "us-east-1b"
  tags = {
    Name                              = "eks_private_subnet_us_east_1b"
    "kubernetes.io/cluster/eks"       = "shared"
    "kubernetes.io/role/internat-elb" = 1
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "main"
  }
}

resource "aws_eip" "nat1" {
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "gw1" {
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.eks_node_group_public_subnet_1.id
  tags = {
    Name = "NAT 1"
  }
}

resource "aws_eip" "nat2" {
  depends_on = [aws_internet_gateway.main]
}
resource "aws_nat_gateway" "gw2" {
  allocation_id = aws_eip.nat2.id
  subnet_id     = aws_subnet.eks_node_group_public_subnet_2.id
  tags = {
    Name = "NAT 2"
  }
}

resource "aws_route_table" "public_route_table_1" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw1
  }
  tags = {
    Name = "private_route_table_1"
  }
}

resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw2
  }
  tags = {
    Name = "private_route_table_2"
  }
}



resource "aws_route_table_association" "public_RTA_1" {
  subnet_id      = aws_subnet.eks_node_group_public_subnet_1
  route_table_id = aws_route_table.public_route_table_1.id
}

resource "aws_route_table_association" "public_RTA_2" {
  subnet_id      = aws_subnet.eks_node_group_public_subnet_2
  route_table_id = aws_route_table.public_route_table_1.id
}


resource "aws_route_table_association" "private_RTA_1" {
  subnet_id      = aws_subnet.eks_node_group_private_subnet_1
  route_table_id = aws_route_table.private_route_table_1.id
}

resource "aws_route_table_association" "private_RTA_2" {
  subnet_id      = aws_subnet.eks_node_group_public_subnet_2
  route_table_id = aws_route_table.private_route_table_2.id
}



resource "aws_security_group" "eks_node_group_security_group" {
  name        = "my-eks-node-group-security-group"
  description = "Security group for EKS node group"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = [aws_vpc.eks_vpc.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}




resource "aws_eks_node_group" "eks_node_group" {
  cluster_name  = aws_eks_cluster.eks.name
  node_role_arn = aws_iam_role.ec2_role.arn
  # node_security_group_ids = [aws_security_group.eks_node_group_security_group.id]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }
  ami_type       = "AL2_x86_64"
  instance_types = ["t3.medium"]

  disk_size            = 20
  force_update_version = false
  subnet_ids = [aws_subnet.eks_node_group_public_subnet_1.id,
    aws_subnet.eks_node_group_public_subnet_2.id,
    aws_subnet.eks_node_group_private_subnet_1.id,
  aws_subnet.eks_node_group_private_subnet_2.id, ]
  depends_on = [aws_iam_role_policy_attachment.ec2_container_registry_read_only_policy_attachment, aws_iam_role_policy_attachment.ec2_eks_cni_policy_attachment, aws_iam_role_policy_attachment.eks_role_policy_attachment]
}


resource "aws_eks_cluster" "eks" {
  name     = "eks"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    endpoint_public_access  = true
    endpoint_private_access = false
    security_group_ids      = [aws_security_group.eks_node_group_security_group.id]
    subnet_ids = [
      aws_subnet.eks_node_group_public_subnet_1.id,
      aws_subnet.eks_node_group_public_subnet_2.id,
      aws_subnet.eks_node_group_private_subnet_1.id,
      aws_subnet.eks_node_group_private_subnet_2.id,
    ]
  }
  depends_on = [aws_iam_role_policy_attachment.eks_role_policy_attachment]
}

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${aws_eks_cluster.eks.name} --region ${var.aws_region}"
  }
}

resource "null_resource" "example" {
  provisioner "local-exec" {
    command = <<-EOF
    kubectl apply -f ./app/helloworld.yaml
    kubectl get node
    kubectl get pod
    kubectl get svc
    culr -I ${aws_eip.nat1.public_ip}:30001
    EOF
  }

  triggers = {
    eks_cluster = aws_eks_cluster.eks.id
    app_config  = "${md5(file("${path.module}/app/helloworld.yaml"))}"
  }
}
