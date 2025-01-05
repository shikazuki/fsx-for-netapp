resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true # svm のマウントに必要
  tags = {
    Name = "${var.prefix}-vpc"
  }
}

resource "aws_subnet" "pri_a_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "${var.prefix}-pri_a_1"
  }
}


# for nat gateway + internet gateway to enable ssm manager
resource "aws_subnet" "pub_a_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "${var.prefix}-pub_a_1"
  }
}

### Gateway ###

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.prefix}-igw"
  }
}


resource "aws_eip" "nat_a_1" {
  domain = "vpc"
  tags = {
    Name = "${var.prefix}-eip-nat_a_1"
  }
}

resource "aws_nat_gateway" "nat_a_1" {
  allocation_id = aws_eip.nat_a_1.id
  subnet_id     = aws_subnet.pub_a_1.id
  depends_on    = [aws_internet_gateway.main]
  tags = {
    Name = "${var.prefix}-nat_a_1"
  }
}

### Route Table ###

resource "aws_route_table" "public_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.prefix}-pub_a_1"
  }
}

resource "aws_route_table" "private_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.prefix}-pri_a_1"
  }
}

resource "aws_route" "igw_route" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public_table.id
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "nat_route" {
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a_1.id
  route_table_id         = aws_route_table.private_table.id
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.pub_a_1.id
  route_table_id = aws_route_table.public_table.id
}


resource "aws_route_table_association" "private_association_a_1" {
  subnet_id      = aws_subnet.pri_a_1.id
  route_table_id = aws_route_table.private_table.id
}
