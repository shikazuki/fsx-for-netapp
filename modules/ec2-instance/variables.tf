variable "name" {
  type        = string
  description = "Name prefix applied to all resource names."
}

variable "ami" {
  type        = string
  description = "AMI to use"
}

variable "vpc_id" {
  type        = string
  description = "VPC Id of the network."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC cidr block of the network."
}

variable "subnet_id" {
  type        = string
  description = "Subnet Id of the bastion host."
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size of root volume for EC2."
}

variable "instance_type" {
  type        = string
  description = "EC2 Instance type."
  default     = "t3.medium"
}
