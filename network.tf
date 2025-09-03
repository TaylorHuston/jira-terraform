# network.tf

# VPC - The main container for everything
resource "aws_vpc" "jira_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "jira-vpc"
  }
}

# Internet Gateway - The door to the internet
resource "aws_internet_gateway" "jira_igw" {
  vpc_id = aws_vpc.jira_vpc.id

  tags = {
    Name = "jira-igw"
  }
}

# Public subnets - Where our ALB will live
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.jira_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "jira-public-subnet"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.jira_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b" # Different AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "jira-public-subnet-2"
  }
}

resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Private subnet - Where Jira will actually run
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.jira_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "jira-private-subnet"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.jira_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "jira-private-subnet-2"
  }
}
# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "jira-nat-eip"
  }
}

# NAT Gateway - Allows private subnet to reach the internet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "jira-nat-gateway"
  }
}

# Route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.jira_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jira_igw.id
  }

  tags = {
    Name = "jira-public-rt"
  }
}

# Associate public route table with public subnet
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Route table for private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.jira_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "jira-private-rt"
  }
}

# Associate private route table with private subnet
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rta_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}
