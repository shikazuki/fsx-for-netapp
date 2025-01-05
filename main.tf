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
  root_volume_size = 50
}


resource "aws_fsx_ontap_file_system" "main" {
  storage_capacity                = 1024
  subnet_ids                      = [module.network.pri_a_1_id]
  deployment_type                 = "SINGLE_AZ_1"
  ha_pairs                        = 1
  throughput_capacity_per_ha_pair = 128
  preferred_subnet_id             = module.network.pri_a_1_id

  tags = {
    Name = "fsx-netapp"
  }
}

resource "aws_fsx_ontap_storage_virtual_machine" "svm" {
  file_system_id = aws_fsx_ontap_file_system.main.id
  name           = "fsx-netapp-svm"
  svm_admin_password = "Password@Difficult" # CAUTION: NOT SECURE
}

resource "aws_fsx_ontap_volume" "volume" {
  name                       = "vol"
  junction_path              = "/vol"
  size_in_megabytes          = 1024
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.svm.id
}
