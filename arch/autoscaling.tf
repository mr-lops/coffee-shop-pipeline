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
    cooldown                = 60              # Período de espera entre ajustes automáticos (em segundos)
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
    */
resource "aws_cloudwatch_metric_alarm" "queue-size-alarm" {
  alarm_name          = "queue-size-alarm"                        # Nome do alarme CloudWatch
  comparison_operator = "GreaterThanOrEqualToThreshold"           # Operador de comparação para a métrica
  evaluation_periods  = "1"                                       # Número de períodos de avaliação antes de ativar o alarme
  metric_name         = "ApproximateNumberOfMessagesVisible"      # Nome da métrica CloudWatch
  namespace           = "AWS/SQS"                                 # Namespace da métrica (SQS)
  period              = "60"                                      # Período de coleta da métrica (em segundos)
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
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Alarm when queue size decreases"
  alarm_actions       = [aws_appautoscaling_policy.scale-up.arn]
  dimensions = {
    QueueName = aws_sqs_queue.ingest-data-queue.name
  }
}