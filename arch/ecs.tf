# Definindo um cluster Amazon ECS
resource "aws_ecs_cluster" "ingest-data-ecs-cluster" {
  name = "ingest-data-ecs-cluster" # Nome do cluster ECS
}

# cria um repositório ECR com o nome "ingest-data-repository".
# O Amazon Elastic Container Registry é um serviço da AWS que permite armazenar, gerenciar e distribuir imagens de contêiner Docker.
resource "aws_ecr_repository" "ingest-data-repository" {
  name = "ingest-data-repository"
}