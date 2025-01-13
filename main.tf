module "network" {
  source = "./modules/network"
}

data "aws_ssm_parameter" "linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64" # x86_64
}

module "linux_instance" {
  source = "./modules/ec2-instance"

  name             = "linux-instance"
  ami              = data.aws_ssm_parameter.linux.insecure_value
  vpc_id           = module.network.vpc_id
  vpc_cidr         = module.network.vpc_cidr
  subnet_id        = module.network.pri_a_1_id
  root_volume_size = 8
}

# Use the below candidates.
#      "Name": "/aws/service/ami-windows-latest/Windows_Server-2016-English-Full-Base"
#      "Name": "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
#      "Name": "/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base"

data "aws_ssm_parameter" "windows" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2016-English-Full-Base"
}

module "windows_instance" {
  source = "./modules/ec2-instance"

  name             = "windows-instance"
  ami              = data.aws_ssm_parameter.windows.insecure_value
  vpc_id           = module.network.vpc_id
  vpc_cidr         = module.network.vpc_cidr
  subnet_id        = module.network.pri_a_1_id
  root_volume_size = 50 # minimum volume size
}

locals {
  prefix = "fsx-netapp"
  ingress_tcp = [
    # [from_port, to_port]
    [22, 22],
    [111, 111],
    [135, 135],
    [139, 139],
    [161, 162],
    [443, 443],
    [445, 445],
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
    [137, 137],
    [139, 139],
    [161, 162],
    [635, 635],
    [2049, 2049],
    [4045, 4046],
    [4049, 4049],
  ]
}

resource "aws_security_group" "main" {
  name   = "${local.prefix}-sg"
  vpc_id = module.network.vpc_id


  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [module.network.vpc_cidr]
  }

  dynamic "ingress" {
    for_each = local.ingress_tcp
    content {
      from_port   = ingress.value[0]
      to_port     = ingress.value[1]
      protocol    = "tcp"
      cidr_blocks = [module.network.vpc_cidr]
    }
  }


  dynamic "ingress" {
    for_each = local.ingress_udp
    content {
      from_port   = ingress.value[0]
      to_port     = ingress.value[1]
      protocol    = "udp"
      cidr_blocks = [module.network.vpc_cidr]
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
resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

output "admin_password" {
  value     = random_password.admin_password.result
  sensitive = true
}

resource "aws_fsx_ontap_file_system" "main" {
  storage_capacity                = 1024
  subnet_ids                      = [module.network.pri_a_1_id]
  security_group_ids              = [aws_security_group.main.id]
  deployment_type                 = "SINGLE_AZ_1"
  ha_pairs                        = 1
  throughput_capacity_per_ha_pair = 128
  preferred_subnet_id             = module.network.pri_a_1_id
  fsx_admin_password              = random_password.admin_password.result

  tags = {
    Name = "${local.prefix}-fs"
  }
}

resource "aws_fsx_ontap_storage_virtual_machine" "svm" {
  file_system_id     = aws_fsx_ontap_file_system.main.id
  name               = "${local.prefix}-svm"
  svm_admin_password = random_password.admin_password.result
}

resource "aws_fsx_ontap_volume" "volume" {
  name                       = "vol"
  junction_path              = "/vol"
  size_in_megabytes          = 1024
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.svm.id
  security_style             = "NTFS"
}
