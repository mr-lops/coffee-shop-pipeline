# Definition of the Virtual Private Cloud (VPC)
resource "aws_vpc" "ingest-data-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Definition of the Public Subnet
resource "aws_subnet" "ingest-data-public-subnet" {
  vpc_id     = aws_vpc.ingest-data-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Ingest Data Public" # Name of the public subnet
  }
}

# Definition of the Private Subnet
resource "aws_subnet" "ingest-data-private-subnet" {
  vpc_id     = aws_vpc.ingest-data-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "Ingest Data Private" # Name of the private subnet
  }
}

# Definition of the Internet Gateway
resource "aws_internet_gateway" "ingest-data-ig" {
  vpc_id = aws_vpc.ingest-data-vpc.id

  tags = {
    Name = "Ingest Data IG" # Name of the Internet Gateway
  }
}

# Definition of the Route Table with Route to the Internet Gateway
resource "aws_route_table" "ingest-data-sec-rt" {
  vpc_id = aws_vpc.ingest-data-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ingest-data-ig.id
  }

  tags = {
    Name = "2nd Route Table" # Name of the route table
  }
}

# Association of the Public Subnet with the Route Table
resource "aws_route_table_association" "public-subnet-asso" {
  route_table_id = aws_route_table.ingest-data-sec-rt.id
  subnet_id      = aws_subnet.ingest-data-public-subnet.id
}

# Definition of the Security Group
resource "aws_security_group" "ingest-data-sg" {
  vpc_id = aws_vpc.ingest-data-vpc.id
  name   = "ingest-data-sg" # Name of the security group
}

# Inbound Security Group Rule (Allowing any Inbound Traffic)
resource "aws_security_group_rule" "sgr-allow-all-in" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.ingest-data-sg.id
  cidr_blocks       = [aws_vpc.ingest-data-vpc.cidr_block]
  to_port           = 0
  type              = "ingress"
}

# Outbound Security Group Rule (Allowing any Outbound Traffic)
resource "aws_security_group_rule" "sgr-allow-all-out" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.ingest-data-sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [aws_vpc.ingest-data-vpc.cidr_block]
}

# Defining a subnet group for Amazon Redshift
resource "aws_redshift_subnet_group" "ingest-data-subnet-group" {
  name       = "ingest-data-subnet-group"                                                          # Subnet group name
  subnet_ids = [aws_subnet.ingest-data-public-subnet.id, aws_subnet.ingest-data-private-subnet.id] # Associated subnet IDs
}
