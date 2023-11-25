# CRIAR uma VPC com 2 subnet e um security group(para o ecs service) para a vpc


# Definindo um grupo de subnets para o Amazon Redshift
resource "aws_redshift_subnet_group" "ingest-data-subnet-group" {
  name       = "ingest-data-subnet-group"                               # Nome do grupo de subnets
  subnet_ids = ["subnet-0f569d8ffdfb95c82", "subnet-0b1081eed0310fc5f"] # IDs das subnets associadas
}