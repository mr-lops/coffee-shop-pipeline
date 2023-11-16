# Cria um bucket S3
resource "aws_s3_bucket" "ingest-data" {
  bucket = "bucket-ingest-21-10-2023"

  force_destroy = true
}

#  cria uma nova fila SQS chamada "ingest-data-queue". A fila será usada para armazenar mensagens relacionadas à ingestão de dados.
resource "aws_sqs_queue" "ingest-data-queue" {
  name = "ingest-data-queue"
}

# Definindo uma política de IAM para permitir que um bucket S3 envie mensagens para uma fila SQS
data "aws_iam_policy_document" "ingest-data-policy" {
  statement {
    # Ação permitida: Enviar mensagem para a fila SQS
    actions = ["sqs:SendMessage"]
    effect  = "Allow"

    # Ação permitida apenas para o serviço S3
    principals {
      identifiers = ["s3.amazonaws.com"]
      type        = "Service"
    }

    # Recurso alvo: ARN da fila SQS
    resources = [aws_sqs_queue.ingest-data-queue.arn]

    # Condição para permitir a ação apenas se o ARN do bucket S3 for semelhante ao especificado como fonte
    condition {
      test     = "ArnLike"
      values   = [aws_s3_bucket.ingest-data.arn]
      variable = "aws:SourceArn"
    }
  }
}

# Criando uma política para a fila SQS usando a política de IAM definida anteriormente
resource "aws_sqs_queue_policy" "ingest-data-queue-policy" {
  # A política da fila é igual à política de IAM definida acima
  policy = data.aws_iam_policy_document.ingest-data-policy.json

  # URL da fila SQS
  queue_url = aws_sqs_queue.ingest-data-queue.id
}


# sempre que um objeto é criado no bucket ingest-data, um evento deve ser enviado para a fila SQS criada anteriormente.
resource "aws_s3_bucket_notification" "ingest-data-bucket-notification" {
  bucket = aws_s3_bucket.ingest-data.id

  queue {
    queue_arn = aws_sqs_queue.ingest-data-queue.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.ingest-data-queue-policy]
}

# Este bloco de recurso cria um repositório ECR com o nome "ingest-data-repository". 
# O Amazon Elastic Container Registry é um serviço da AWS que permite armazenar, gerenciar e distribuir imagens de contêiner Docker.
resource "aws_ecr_repository" "ingest-data-repository" {
  name = "ingest-data-repository"
}

# Este bloco de recurso cria um grupo de logs do CloudWatch com o nome "ingest-data-log-group". 
# O Amazon CloudWatch é um serviço de monitoramento e registro da AWS que permite coletar, armazenar e consultar logs e métricas.
resource "aws_cloudwatch_log_group" "ingest-data-log-group" {
  name              = "ingest-data-log-group"
  retention_in_days = 15
}

# Definindo a IAM Role para a execução de tarefas ECS
resource "aws_iam_role" "ecs-execution-role" {
  name = "ecs-execution-role"

  # Política que permite que as tarefas ECS sejam executadas
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

# Anexando uma política predefinida à IAM Role de execução ECS
resource "aws_iam_policy_attachment" "ecs-execution-role" {
  name       = "AmazonECSTaskExecutionRolePolicy"
  roles      = [aws_iam_role.ecs-execution-role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Definindo a IAM Role para tarefas ECS
resource "aws_iam_role" "ecs-task-role" {
  name = "ecs-task-role"

  # Política que permite que as tarefas ECS interajam com recursos específicos
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

# Definindo uma política personalizada para permitir interações com Redshift, S3 e SQS
resource "aws_iam_policy" "ecs-redshift-access" {
  name        = "ecs-redshift-access"
  description = "Permite a task ECS interagir com o Redshift"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "redshift:GetClusterCredentials",
          "Resource" : "${aws_redshift_cluster.redshift-cluster.arn}"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:GetObject",
            "s3:ListBucket"
          ],
          "Resource" : [
            "${aws_s3_bucket.ingest-data.arn}",
            "${aws_s3_bucket.ingest-data.arn}/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : ["sqs:ReceiveMessage", "sqs:ChangeMessageVisibility", "sqs:DeleteMessage"],
          "Resource" : "${aws_sqs_queue.ingest-data-queue.arn}"
        }
      ]
    }
  )
}

# Anexando a política personalizada à IAM Role de tarefas ECS
resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment" {
  policy_arn = aws_iam_policy.ecs-redshift-access.arn
  role       = aws_iam_role.ecs-task-role.arn
}


# CRIAR PROPRIA SUBNET e VPC
# Definindo um grupo de subnets para o Amazon Redshift
resource "aws_redshift_subnet_group" "ingest-data-subnet-group" {
  name       = "ingest-data-subnet-group"                               # Nome do grupo de subnets
  subnet_ids = ["subnet-0f569d8ffdfb95c82", "subnet-0b1081eed0310fc5f"] # IDs das subnets associadas
}

# Criando um cluster Amazon Redshift
resource "aws_redshift_cluster" "redshift-cluster" {
  cluster_identifier        = "redshift-cluster"                                      # Identificador único para o cluster Redshift
  database_name             = "ingest_data"                                           # Nome do banco de dados dentro do cluster
  master_username           = var.master_username                                     # Usuário mestre para autenticação no banco de dados
  master_password           = var.master_password                                     # Senha do usuário mestre
  node_type                 = "dc2.large"                                             # Tipo de nó para o cluster
  cluster_type              = "single_node"                                           # Tipo de cluster (neste caso, um único nó)
  number_of_nodes           = 1                                                       # Número de nós no cluster
  publicly_accessible       = true                                                    # Cluster é acessível publicamente (RECOMENDA-SE deixar como false e acessar via VPN ou IP específico)
  vpc_security_group_ids    = ["vpc-0446dace6defaf5f9"]                               # IDs dos grupos de segurança associados ao cluster
  skip_final_snapshot       = true                                                    # Ignorar a criação de um snapshot final quando o cluster for excluído
  cluster_subnet_group_name = aws_redshift_subnet_group.ingest-data-subnet-group.name # Nome do grupo de subnets associado ao cluster
}

# Definindo um cluster Amazon ECS
resource "aws_ecs_cluster" "ingest-data-ecs-cluster" {
  name = "ingest-data-ecs-cluster" # Nome do cluster ECS
}

# Definindo uma definição de tarefa para o Amazon ECS
resource "aws_ecs_task_definition" "ingest-data-task" {
  family                   = "inges-daa-task"                    # Nome da família da tarefa
  requires_compatibilities = ["FARGATE"]                         # Tipo de compatibilidade da tarefa (FARGATE para uso sem servidor)
  network_mode             = "awsvpc"                            # Modo de rede da tarefa
  cpu                      = "256"                               # Unidades de CPU alocadas para a tarefa
  memory                   = "512"                               # Memória alocada para a tarefa
  execution_role_arn       = aws_iam_role.ecs-execution-role.arn # ARN da função de execução da tarefa
  task_role_arn            = aws_iam_role.ecs-task-role.arn      # ARN da função da tarefa

  # Dentro do jsonencode tem uma lista pois é possivel definir mais de um container
  container_definitions = jsonencode([{
    name      = "ingest-data-image"                                                  # Nome do contêiner
    image     = "${aws_ecr_repository.ingest-data-repository.repository_url}:latest" # URL da imagem do repositório ECR
    essential = true                                                                 # Indica que o contêiner é essencial para a tarefa
    logConfiguration : {
      "logDriver" : "awslogs", # Configuração de log usando CloudWatch Logs
      options : {
        "awslogs-group" : aws_cloudwatch_log_group.ingest-data-log-group.name, # Nome do grupo de logs do CloudWatch
        "awslogs-region" : "us-east-1",                                        # Região do CloudWatch Logs
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

# Definindo um alvo de escala para o serviço ECS
resource "aws_appautoscaling_target" "autoscaling-target" {
  max_capacity       = 1                                                                                                     # Número máximo de instâncias ou tarefas que o autoescala pode ajustar
  min_capacity       = 0                                                                                                     # Número mínimo de instâncias ou tarefas que o autoescala pode ajustar (pode ser zero para ECS)
  resource_id        = "service/${aws_ecs_cluster.ingest-data-ecs-cluster.name}/${aws_ecs_service.ingest-data-service.name}" # Identificador do recurso ECS a ser autoescalado
  scalable_dimension = "ecs:service:DesiredCount"                                                                            # Dimensão a ser ajustada (contagem de tarefas desejada)
  service_namespace  = "ecs"                                                                                                 # Namespace do serviço (ECS para Elastic Container Service)
}

# Definindo uma política de escala para aumentar a contagem de tarefas ECS
resource "aws_appautoscaling_policy" "scale-up" {
  name               = "scale-up"                                                      # Nome da política de autoescala
  resource_id        = aws_appautoscaling_target.autoscaling-target.resource_id        # ID do recurso a ser autoescalado
  scalable_dimension = aws_appautoscaling_target.autoscaling-target.scalable_dimension # Dimensão a ser ajustada pela política
  service_namespace  = aws_appautoscaling_target.autoscaling-target.service_namespace  # Namespace do serviço (ECS)
  policy_type        = "StepScaling"                                                   # Tipo de política de autoescala (escala em etapas)

  # Configuração da política de escala em etapas
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity" # Tipo de ajuste (alteração na capacidade)
    cooldown                = 300                # Período de espera entre ajustes automáticos (em segundos)
    metric_aggregation_type = "Average"          # Tipo de agregação da métrica (média)

    # Definindo o ajuste da contagem de tarefas ECS quando o alarme é acionado
    step_adjustment {
      metric_interval_lower_bound = 0 # Limite inferior do intervalo da métrica
      scaling_adjustment          = 1 # Ajuste da contagem de tarefas (aumentar em 1)
    }
  }
}

# Definindo um alarme CloudWatch para o tamanho da fila SQS
resource "aws_cloudwatch_metric_alarm" "queue-size-alarm" {
  alarm_name          = "queue-size-alarm"                        # Nome do alarme CloudWatch
  comparison_operator = "GreaterThanOrEqualToThreshold"           # Operador de comparação para a métrica
  evaluation_periods  = "1"                                       # Número de períodos de avaliação antes de ativar o alarme
  metric_name         = "ApproximateNumberOfMessagesVisible"      # Nome da métrica CloudWatch
  namespace           = "AWS/SQS"                                 # Namespace da métrica (SQS)
  period              = "300"                                     # Período de coleta da métrica (em segundos)
  statistic           = "Maximum"                                 # Estatística usada para avaliar a métrica (máximo)
  threshold           = "1"                                       # Limiar para acionar o alarme (quando o tamanho da fila é 1 ou mais)
  alarm_description   = "Alarme quando o tamanho da fila aumenta" # Descrição do alarme

  # Ação a ser tomada quando o alarme é acionado (aumentar a contagem de tarefas ECS)
  alarm_actions = [aws_appautoscaling_policy.scale-up.arn]

  # Dimensões para o alarme (nome da fila SQS)
  dimensions = {
    QueueName = aws_sqs_queue.ingest-data-queue.name
  }
}
