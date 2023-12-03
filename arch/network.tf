# Definição da Virtual Private Cloud (VPC)
resource "aws_vpc" "ingest-data-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Definição da Sub-rede Pública
resource "aws_subnet" "ingest-data-public-subnet" {
  vpc_id     = aws_vpc.ingest-data-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Ingest Data Public" # Nome da sub-rede pública
  }
}

# Definição da Sub-rede Privada
resource "aws_subnet" "ingest-data-private-subnet" {
  vpc_id     = aws_vpc.ingest-data-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "Ingest Data Private" # Nome da sub-rede privada
  }
}

# Definição do Internet Gateway
resource "aws_internet_gateway" "ingest-data-ig" {
  vpc_id = aws_vpc.ingest-data-vpc.id

  tags = {
    Name = "Ingest Data IG" # Nome do Internet Gateway
  }
}

# Definição da Tabela de Roteamento com Rota para o Internet Gateway
resource "aws_route_table" "ingest-data-sec-rt" {
  vpc_id = aws_vpc.ingest-data-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ingest-data-ig.id
  }

  tags = {
    Name = "2nd Route Table" # Nome da tabela de roteamento
  }
}

# Associação da Sub-rede Pública à Tabela de Roteamento
resource "aws_route_table_association" "public-subnet-asso" {
  route_table_id = aws_route_table.ingest-data-sec-rt.id
  subnet_id      = aws_subnet.ingest-data-public-subnet.id
}

# Definição do Grupo de Segurança
resource "aws_security_group" "ingest-data-sg" {
  vpc_id = aws_vpc.ingest-data-vpc.id
  name   = "ingest-data-sg" # Nome do grupo de segurança
}

# Regra de Segurança de Entrada (Permitindo qualquer Tráfego de Entrada)
resource "aws_security_group_rule" "sgr-allow-all-in" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.ingest-data-sg.id
  cidr_blocks       = [aws_vpc.ingest-data-vpc.cidr_block]
  to_port           = 0
  type              = "ingress"
}

# Regra de Segurança de Saída (Permitindo qualquer Tráfego de Saída)
resource "aws_security_group_rule" "sgr-allow-all-out" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.ingest-data-sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [aws_vpc.ingest-data-vpc.cidr_block]
}

# Definindo um grupo de subnets para o Amazon Redshift
resource "aws_redshift_subnet_group" "ingest-data-subnet-group" {
  name       = "ingest-data-subnet-group"                                                          # Nome do grupo de subnets
  subnet_ids = [aws_subnet.ingest-data-public-subnet.id, aws_subnet.ingest-data-private-subnet.id] # IDs das subnets associadas
}
