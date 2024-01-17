# Defining an Amazon ECS cluster
resource "aws_ecs_cluster" "ingest-data-ecs-cluster" {
  name = "ingest-data-ecs-cluster" # Name of the ECS cluster
}

# Creates an ECR repository with the name "ingest-data-repository".
# Amazon Elastic Container Registry is an AWS service that allows storing, managing, and distributing Docker container images.
resource "aws_ecr_repository" "ingest-data-repository" {
  name = "ingest-data-repository"
}

# This resource block creates a CloudWatch log group with the name "ingest-data-log-group".
# Amazon CloudWatch is an AWS monitoring and logging service that allows collecting, storing, and querying logs and metrics.
resource "aws_cloudwatch_log_group" "ingest-data-log-group" {
  name              = "ingest-data-log-group"
  retention_in_days = 14
}

# Creates an ECS task definition to run the container; the ECS task definition defines how the task will be executed.
resource "aws_ecs_task_definition" "ingest-data-task" {
  family                   = "ingest-data-task"             # Task family name
  requires_compatibilities = ["FARGATE"]                    # Task compatibility type (FARGATE for serverless usage)
  network_mode             = "awsvpc"                       # Task network mode
  cpu                      = "1024"                         # CPU units allocated for the task
  memory                   = "2048"                         # Memory allocated for the task
  execution_role_arn       = aws_iam_role.ecs-task-role.arn # ARN of the task execution role
  task_role_arn            = aws_iam_role.ecs-task-role.arn # ARN of the task role

  # Defines the ECS task runtime platform.
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  # Inside the jsonencode is a list since it's possible to define more than one container
  container_definitions = jsonencode([{
    name      = "ingest-data-image"                                                  # Container name
    image     = "${aws_ecr_repository.ingest-data-repository.repository_url}:latest" # ECR repository image URL
    essential = true                                                                 # Indicates that the container is essential for the task
    logConfiguration : {
      "logDriver" : "awslogs", # Log configuration using CloudWatch Logs
      options : {
        "awslogs-group" : aws_cloudwatch_log_group.ingest-data-log-group.name, # CloudWatch log group name
        "awslogs-region" : var.credentials.region,                             # CloudWatch Logs region
        "awslogs-stream-prefix" : "ecs"                                        # Log stream prefix
      }
    },
    environment : [
      {
        name : "redshift_host", # Environment variable for Amazon Redshift host
        value : aws_redshift_cluster.redshift-cluster.dns_name
      },
      {
        name : "redshift_user", # Environment variable for Amazon Redshift user
        value : var.master_username
      },
      {
        name : "redshift_password", # Environment variable for Amazon Redshift password
        value : var.master_password
      },
      {
        name : "redshift_db", # Environment variable for Amazon Redshift database name
        value : aws_redshift_cluster.redshift-cluster.database_name
      },
      {
        name : "sqs_queue_url", # Environment variable for SQS queue URL
        value : aws_sqs_queue.ingest-data-queue.id
      }
    ]
  }])
}

# Creating an ECS service
resource "aws_ecs_service" "ingest-data-service" {
  name            = "ingest-data-service"                        # ECS service name
  cluster         = aws_ecs_cluster.ingest-data-ecs-cluster.id   # ECS cluster ID
  task_definition = aws_ecs_task_definition.ingest-data-task.arn # ARN of the ECS task definition
  desired_count   = 0                                            # Desired number of running tasks
  launch_type     = "FARGATE"                                    # Task launch type (FARGATE for serverless usage)

  network_configuration {
    subnets          = [aws_subnet.ingest-data-private-subnet.id, aws_subnet.ingest-data-public-subnet.id] # Subnet IDs for the task
    security_groups  = [aws_security_group.ingest-data-sg.id]                                              # Security group IDs associated with the task
    assign_public_ip = true                                                                                # Allows assigning a public IP to the task (NOT RECOMMENDED for production)
  }
}
