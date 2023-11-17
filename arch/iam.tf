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
      values   = [aws_s3_bucket.ingest-data-bucket.arn]
      variable = "aws:SourceArn"
    }
  }
  depends_on = [aws_sqs_queue.ingest-data-queue, aws_s3_bucket.ingest-data-bucket]
}

data "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  /**
    * Policy para execução de tarefas ECS, necessária para que o ECS possa executar as tarefas.
    * https://docs.aws.amazon.com/pt_br/AmazonECS/latest/developerguide/task_execution_IAM_role.html
    */
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Role para execução de tarefas ECS, necessária para que o ECS possa executar as tarefas.
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

# Definindo uma política para permitir que o ECS acesse o Redshift, S3 e SQS
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
            "${aws_s3_bucket.ingest-data-bucket.arn}",
            "${aws_s3_bucket.ingest-data-bucket.arn}/*"
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

# Anexa a policy AmazonECSTaskExecutionRolePolicy à role ecs_task_role
# Isso permite que a role ecs_task_role possua as permissões da policy
resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecs-task-role.name
  policy_arn = data.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn
}


# Anexa a policy ecs_redshift_access à role ecs_task_role.
# Isso permite que a role ecs_task_role possua as permissões da policy ecs_redshift_access.
resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attach" {
  policy_arn = aws_iam_policy.ecs-redshift-access.arn
  role       = aws_iam_role.ecs-task-role.arn
}

# Anexa a policy ingest-data-policy à fila ingest-data-queue.
# Isso permite que a fila ingest-data-queue possua as permissões da policy ingest-data-policy.
resource "aws_sqs_queue_policy" "ingest-data-queue-policy" {
  # A política da fila é igual à política de IAM definida
  policy = data.aws_iam_policy_document.ingest-data-policy.json
  # URL da fila SQS
  queue_url = aws_sqs_queue.ingest-data-queue.id
}
