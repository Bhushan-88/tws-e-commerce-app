data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "jenkins" {
  key_name   = var.ec2_key_name
  public_key = file("${path.module}/terra-key.pub")
}

resource "aws_security_group" "ec2" {
  name        = "${var.cluster_name}-ec2-access"
  description = "Access rules for the EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from any IPv4 address"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins from any IPv4 address"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-ec2-access"
  })
}

resource "aws_security_group_rule" "ec2_to_eks_api" {
  description              = "Allow the EC2 instance to reach the EKS API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.ec2.id
}

resource "aws_iam_role" "jenkins" {
  name = "${var.cluster_name}-jenkins-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "jenkins_eks_describe" {
  name = "${var.cluster_name}-eks-describe"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = module.eks.cluster_arn
    }]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.cluster_name}-jenkins-ec2"
  role = aws_iam_role.jenkins.name
  tags = local.tags
}

resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins_edit" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jenkins]
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  key_name                    = aws_key_pair.jenkins.key_name
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.ec2_root_volume_size
    volume_type = "gp3"
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-jenkins"
  })
}
