output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "pri_a_1_id" {
  value = aws_subnet.pri_a_1.id
}
