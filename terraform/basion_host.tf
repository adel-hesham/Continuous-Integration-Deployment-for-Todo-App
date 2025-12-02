resource "aws_security_group" "basion_host_ec2_sg" {
  name   = "allow_ssh_http_for_basion_host"
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

resource "aws_instance" "basion_host_ec2" {
  ami                         = "ami-0ecb62995f68bb549"
  subnet_id                   = aws_subnet.public_AZ1.id
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.basion_host_ec2_sg.id]
  key_name                    = aws_key_pair.my_key.id
  associate_public_ip_address = true


  tags = {
    Name = "basion_host"
  }
}