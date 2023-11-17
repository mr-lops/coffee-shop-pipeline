# Este bloco de recurso cria um grupo de logs do CloudWatch com o nome "ingest-data-log-group".
# O Amazon CloudWatch é um serviço de monitoramento e registro da AWS que permite coletar, armazenar e consultar logs e métricas.
resource "aws_cloudwatch_log_group" "ingest-data-log-group" {
  name              = "ingest-data-log-group"
  retention_in_days = 14
}


# CRIAR uma VPC com 2 subnet
# Definindo um grupo de subnets para o Amazon Redshift
resource "aws_redshift_subnet_group" "ingest-data-subnet-group" {
  name       = "ingest-data-subnet-group"                               # Nome do grupo de subnets
  subnet_ids = ["subnet-0f569d8ffdfb95c82", "subnet-0b1081eed0310fc5f"] # IDs das subnets associadas
}

# Criando um cluster Amazon Redshift
resource "aws_redshift_cluster" "redshift-cluster" {
  cluster_identifier        = "redshift-cluster"                                      # Identificador único para o cluster Redshift
  database_name             = "ingest-data-db"                                        # Nome do banco de dados dentro do cluster
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

# Definindo um alvo de escala para o serviço ECS
resource "aws_appautoscaling_target" "autoscaling-target" {
  max_capacity       = 1                                                                                                     # Número máximo de tarefas que serão executadas, quando o serviço ECS for escalonado.
  min_capacity       = 0                                                                                                     # Número mínimo de tarefas que serão executadas, quando o serviço ECS for escalonado.
  resource_id        = "service/${aws_ecs_cluster.ingest-data-ecs-cluster.name}/${aws_ecs_service.ingest-data-service.name}" # Define qual serviço ECS que será escalonado.
  scalable_dimension = "ecs:service:DesiredCount"                                                                            # Define que o alvo de escalonamento automático será a quantidade de tarefas que serão executadas.
  service_namespace  = "ecs"                                                                                                 # Define que o alvo de escalonamento automático será um serviço ECS.
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
    adjustment_type         = "ExactCapacity" # Tipo de ajuste (capacidade Exata)
    cooldown                = 90              # Período de espera entre ajustes automáticos (em segundos)
    metric_aggregation_type = "Maximum"       # Tipo de agregação da métrica (Maxima)

    # Definindo o ajuste da contagem de tarefas ECS quando o alarme é acionado
    step_adjustment {
      metric_interval_lower_bound = 0 # Limite inferior do intervalo da métrica
      scaling_adjustment          = 1 # Ajuste da contagem de tarefas (aumentar em 1)
    }
  }
}

/**
    * Cria um alarme do CloudWatch para monitorar o tamanho da fila SQS.
    * O alarme do CloudWatch define quando o alvo de escalonamento automático será escalonado.
    * Quando o alarme do CloudWatch for acionado, o alvo de escalonamento automático será escalonado.
    * Quando o alarme do CloudWatch for desacionado, o alvo deve ser escalonado para a quantidade mínima de tarefas.
    * https://docs.aws.amazon.com/pt_br/AmazonECS/latest/developerguide/service-auto-scaling.html
    */
resource "aws_cloudwatch_metric_alarm" "queue-size-alarm" {
  alarm_name          = "queue-size-alarm"                        # Nome do alarme CloudWatch
  comparison_operator = "GreaterThanOrEqualToThreshold"           # Operador de comparação para a métrica
  evaluation_periods  = "1"                                       # Número de períodos de avaliação antes de ativar o alarme
  metric_name         = "ApproximateNumberOfMessagesVisible"      # Nome da métrica CloudWatch
  namespace           = "AWS/SQS"                                 # Namespace da métrica (SQS)
  period              = "90"                                      # Período de coleta da métrica (em segundos)
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

resource "aws_appautoscaling_policy" "scale_down" {
  /**
    * Cria uma política de escalonamento automático para o alvo de escalonamento automático.
    * Essa policie coloca o alvo de escalonamento automático para 0 quando o alarme do CloudWatch for acionado.
    * https://docs.aws.amazon.com/pt_br/AmazonECS/latest/developerguide/service-auto-scaling.html
    */
  name               = "scale_down"
  service_namespace  = aws_appautoscaling_target.autoscaling-target.service_namespace
  scalable_dimension = aws_appautoscaling_target.autoscaling-target.scalable_dimension
  resource_id        = aws_appautoscaling_target.autoscaling-target.resource_id
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 60
    metric_aggregation_type = "Minimum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_without_message_alarm" {
  /**
    * Cria um alarme do CloudWatch para monitorar o tamanho da fila SQS.
    * Quando o alarme do CloudWatch for acionado, o alvo deve ser escalonado para 0.
    * https://docs.aws.amazon.com/pt_br/AmazonECS/latest/developerguide/service-auto-scaling.html
    */
  alarm_name          = "queue_size_alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "90"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Alarm when queue size decreases"
  alarm_actions       = [aws_appautoscaling_policy.scale-up.arn]
  dimensions = {
    QueueName = aws_sqs_queue.ingest-data-queue.name
  }
}