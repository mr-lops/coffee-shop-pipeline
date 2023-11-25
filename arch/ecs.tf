# Definindo um cluster Amazon ECS
resource "aws_ecs_cluster" "ingest-data-ecs-cluster" {
  name = "ingest-data-ecs-cluster" # Nome do cluster ECS
}

# cria um repositório ECR com o nome "ingest-data-repository".
# O Amazon Elastic Container Registry é um serviço da AWS que permite armazenar, gerenciar e distribuir imagens de contêiner Docker.
resource "aws_ecr_repository" "ingest-data-repository" {
  name = "ingest-data-repository"
}

# Este bloco de recurso cria um grupo de logs do CloudWatch com o nome "ingest-data-log-group".
# O Amazon CloudWatch é um serviço de monitoramento e registro da AWS que permite coletar, armazenar e consultar logs e métricas.
resource "aws_cloudwatch_log_group" "ingest-data-log-group" {
  name              = "ingest-data-log-group"
  retention_in_days = 14
}

# Definindo uma definição de tarefa para o Amazon ECS
resource "aws_ecs_task_definition" "ingest-data-task" {
  family                   = "ingest-data-task"             # Nome da família da tarefa
  requires_compatibilities = ["FARGATE"]                    # Tipo de compatibilidade da tarefa (FARGATE para uso sem servidor)
  network_mode             = "awsvpc"                       # Modo de rede da tarefa
  cpu                      = "1024"                         # Unidades de CPU alocadas para a tarefa
  memory                   = "2048"                         # Memória alocada para a tarefa
  execution_role_arn       = aws_iam_role.ecs-task-role.arn # ARN da função de execução da tarefa
  task_role_arn            = aws_iam_role.ecs-task-role.arn # ARN da função da tarefa

  # Define a plataforma de execução da tarefa ECS.
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  # Dentro do jsonencode tem uma lista pois é possivel definir mais de um container
  container_definitions = jsonencode([{
    name      = "ingest-data-image"                                                  # Nome do contêiner
    image     = "${aws_ecr_repository.ingest-data-repository.repository_url}:latest" # URL da imagem do repositório ECR
    essential = true                                                                 # Indica que o contêiner é essencial para a tarefa
    logConfiguration : {
      "logDriver" : "awslogs", # Configuração de log usando CloudWatch Logs
      options : {
        "awslogs-group" : aws_cloudwatch_log_group.ingest-data-log-group.name, # Nome do grupo de logs do CloudWatch
        "awslogs-region" : var.credentials.region,                             # Região do CloudWatch Logs
        "awslogs-stream-prefix" : "ecs"                                        # Prefixo do stream de logs
      }
    },
    environment : [
      {
        name : "redshift_host", # Variável de ambiente para o host do Amazon Redshift
        value : aws_redshift_cluster.redshift-cluster.endpoint
      },
      {
        name : "redshift_user", # Variável de ambiente para o usuário do Amazon Redshift
        value : var.master_username
      },
      {
        name : "redshift_password", # Variável de ambiente para a senha do Amazon Redshift
        value : var.master_password
      },
      {
        name : "redshift_db", # Variável de ambiente para o nome do banco de dados Amazon Redshift
        value : aws_redshift_cluster.redshift-cluster.database_name
      },
      {
        name : "sqs_queue_url", # Variável de ambiente para a URL da fila SQS
        value : aws_sqs_queue.ingest-data-queue.id
      }
    ]
  }])
}

# Criando um serviço Amazon ECS
resource "aws_ecs_service" "ingest-data-service" {
  name            = "ingest-data-service"                        # Nome do serviço ECS
  cluster         = aws_ecs_cluster.ingest-data-ecs-cluster.id   # ID do cluster ECS
  task_definition = aws_ecs_task_definition.ingest-data-task.arn # ARN da definição da tarefa ECS
  desired_count   = 0                                            # Número desejado de tarefas em execução
  launch_type     = "FARGATE"                                    # Tipo de lançamento da tarefa (FARGATE para uso sem servidor)

  network_configuration {
    subnets          = ["subnet-0f569d8ffdfb95c82", "subnet-0b1081eed0310fc5f"] # IDs das subnets para a tarefa
    security_groups  = ["sg-04fff701f33798c5a"]                                 # IDs do grupo de segurança associado à tarefa
    assign_public_ip = true                                                     # Permite a atribuição de um IP público à tarefa (NÃO RECOMENDADO para produção)
  }
}