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

locals {
  ingress_tcp = [
    # [from_port, to_port]
    [22, 22],
    [111, 111],
    [135, 135],
    [139, 139],
    [161, 162],
    [443, 443],
    [635, 635],
    [749, 749],
    [2049, 2049],
    [3260, 3260],
    [4045, 4046],
    [10000, 10000],
    [11104, 11105],
  ]
  ingress_udp = [
    # [from_port, to_port]
    [111, 111],
    [135, 135],
    [139, 139],
    [635, 635],
    [2049, 2049],
    [4045, 4046],
    [4049, 4049],
  ]
}

resource "aws_security_group" "main" {
  name   = "${var.name}-sg"
  vpc_id = var.vpc_id


  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  dynamic "ingress" {
    for_each = local.ingress_tcp
    content {
      from_port   = ingress.value[0]
      to_port     = ingress.value[1]
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }


  dynamic "ingress" {
    for_each = local.ingress_udp
    content {
      from_port   = ingress.value[0]
      to_port     = ingress.value[1]
      protocol    = "udp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All traffic is allowed"
  }
}

resource "aws_instance" "main" {
  ami                  = var.ami
  instance_type        = var.instance_type
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