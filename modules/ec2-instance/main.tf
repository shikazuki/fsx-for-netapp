data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "main" {
  name = "${var.name}-profile"
  role = aws_iam_role.main.name
}

resource "aws_security_group" "main" {
  name   = "${var.name}-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All traffic is allowed"
  }
}

# To connect by using Windows Fleet Manager
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "main" {
  key_name   = var.name
  public_key = tls_private_key.main.public_key_openssh
}
resource "aws_ssm_parameter" "keypair_pem" {
  name  = "/${var.name}/keypair.pem"
  value = tls_private_key.main.private_key_pem
  type  = "SecureString"
}
resource "aws_ssm_parameter" "keypair_pub" {
  name  = "/${var.name}/keypair.pub"
  value = tls_private_key.main.public_key_openssh
  type  = "SecureString"
}

resource "aws_instance" "main" {
  ami                  = var.ami
  instance_type        = var.instance_type
  key_name             = aws_key_pair.main.key_name
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.main.name
  vpc_security_group_ids = [
    aws_security_group.main.id
  ]
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name = "${var.name}-server"
  }
}