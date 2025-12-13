resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"

      }
    ]
  })
}
resource "aws_iam_policy" "ssm_s3_policy" {
  name        = "ssm-s3-policy"
  description = "Allow SSM to use S3 bucket for Ansible"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-adel-bucket-1234",
          "arn:aws:s3:::my-adel-bucket-1234/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.ssm_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}



resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_ebs_volume" "nexus_data" {
  availability_zone = local.AZ1
  size              = 40
  type              = "gp2"
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Name = "NexusData"
  }
}
import {
  to = aws_ebs_volume.nexus_data
  id = "vol-0a609e0b410e390a4" # Replace with your actual Volume ID
}
# 5️⃣ Attach EBS to EC2
resource "aws_volume_attachment" "ebs_attach" {
  device_name  = "/dev/sdf"
  volume_id    = aws_ebs_volume.nexus_data.id
  instance_id  = aws_instance.my_nexus_ec2.id
  force_detach = true
}
resource "aws_security_group" "nexus_ec2_sg" {
  name   = "allow_ssh_http"
  vpc_id = aws_vpc.main.id

  # Ingress: Allow SSH (22) and HTTP (80) from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
  }
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow nexus"
  }
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow http docker-container-registry"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }

  # Outbound everything is fine and stateful (default behavior)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_nexus_ec2" {
  ami                         = "ami-0ecb62995f68bb549"
  subnet_id                   = aws_subnet.private_AZ1.id
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.nexus_ec2_sg.id]
  key_name                    = aws_key_pair.my_key.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  # Install a web server using user-data
  user_data = <<-EOF
    #!/bin/bash
    sudo snap install amazon-ssm-agent --classic
    sudo systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service
  
  EOF

  tags = {
    Name = "nexus-repo"
  }
}

#############################################################################

