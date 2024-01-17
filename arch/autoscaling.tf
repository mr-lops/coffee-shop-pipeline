# Defining a scaling target for the ECS service
resource "aws_appautoscaling_target" "autoscaling-target" {
  max_capacity       = 1                                                                                                     # Maximum number of tasks to be executed when the ECS service is scaled.
  min_capacity       = 0                                                                                                     # Minimum number of tasks to be executed when the ECS service is scaled.
  resource_id        = "service/${aws_ecs_cluster.ingest-data-ecs-cluster.name}/${aws_ecs_service.ingest-data-service.name}" # Specifies which ECS service will be scaled.
  scalable_dimension = "ecs:service:DesiredCount"                                                                            # Specifies that the auto-scaling target will be the number of tasks to be executed.
  service_namespace  = "ecs"                                                                                                 # Specifies that the auto-scaling target will be an ECS service.
}

# Defining a scale-up policy to increase the ECS task count
resource "aws_appautoscaling_policy" "scale-up" {
  name               = "scale-up"                                                      # Name of the autoscale policy
  resource_id        = aws_appautoscaling_target.autoscaling-target.resource_id        # ID of the resource to be autoscaled
  scalable_dimension = aws_appautoscaling_target.autoscaling-target.scalable_dimension # Dimension to be adjusted by the policy
  service_namespace  = aws_appautoscaling_target.autoscaling-target.service_namespace  # Service namespace (ECS)
  policy_type        = "StepScaling"                                                   # Type of autoscale policy (step scaling)

  # Configuration of the step scaling policy
  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity" # Adjustment type (Exact capacity)
    cooldown                = 60              # Waiting period between automatic adjustments (in seconds)
    metric_aggregation_type = "Maximum"       # Metric aggregation type (Maximum)

    # Setting the adjustment of the ECS task count when the alarm is triggered
    step_adjustment {
      metric_interval_lower_bound = 0 # Lower bound of the metric interval
      scaling_adjustment          = 1 # Task count adjustment (increase by 1)
    }
  }
}

# Defining a scale-down policy to decrease the ECS task count
resource "aws_appautoscaling_policy" "scale_down" {
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

# Creates a CloudWatch alarm to monitor the size of the SQS queue; the alarm aims to increase the number of scaled resources
resource "aws_cloudwatch_metric_alarm" "queue-size-alarm" {
  alarm_name          = "queue-size-alarm"                    # Name of the CloudWatch alarm
  comparison_operator = "GreaterThanOrEqualToThreshold"       # Comparison operator for the metric
  evaluation_periods  = "1"                                   # Number of evaluation periods before triggering the alarm
  metric_name         = "ApproximateNumberOfMessagesVisible"  # Name of the CloudWatch metric
  namespace           = "AWS/SQS"                             # Metric namespace (SQS)
  period              = "60"                                  # Collection period of the metric (in seconds)
  statistic           = "Maximum"                             # Statistic used to evaluate the metric (maximum)
  threshold           = "1"                                   # Threshold to trigger the alarm (when the queue size is 1 or more)
  alarm_description   = "Alarm when the queue size increases" # Alarm description

  # Action to be taken when the alarm is triggered (increase the ECS task count)
  alarm_actions = [aws_appautoscaling_policy.scale-up.arn]

  # Dimensions for the alarm (SQS queue name)
  dimensions = {
    QueueName = aws_sqs_queue.ingest-data-queue.name
  }
}

# Creates a CloudWatch alarm to monitor the size of the SQS queue; the alarm aims to decrease the number of scaled resources
resource "aws_cloudwatch_metric_alarm" "queue_without_message_alarm" {
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
