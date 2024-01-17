# Defining an IAM policy to allow an S3 bucket to send messages to an SQS queue
data "aws_iam_policy_document" "ingest-data-policy" {
  statement {
    # Allowed action: Send message to SQS queue
    actions = ["sqs:SendMessage"]
    effect  = "Allow"

    # Allowed action only for the S3 service
    principals {
      identifiers = ["s3.amazonaws.com"]
      type        = "Service"
    }

    # Target resource: SQS queue ARN
    resources = [aws_sqs_queue.ingest-data-queue.arn]

    # Condition to allow the action only if the S3 bucket ARN is similar to the specified source
    condition {
      test     = "ArnLike"
      values   = [aws_s3_bucket.ingest-data-bucket.arn]
      variable = "aws:SourceArn"
    }
  }
  depends_on = [aws_sqs_queue.ingest-data-queue, aws_s3_bucket.ingest-data-bucket]
}

# Policy for ECS task execution, required for ECS to execute tasks.
data "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Role for ECS task execution, required for ECS to execute tasks.
resource "aws_iam_role" "ecs-task-role" {
  name = "ecs-task-role"

  # Policy allowing ECS tasks to interact with specific resources
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

# Defining a policy to allow ECS to access Redshift, S3, and SQS
resource "aws_iam_policy" "ecs-redshift-access" {
  name        = "ecs-redshift-access"
  description = "Allows ECS task to interact with Redshift"

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

# Attaches the AmazonECSTaskExecutionRolePolicy policy to the ecs_task_role role
# This allows the ecs_task_role role to have the permissions of the policy
resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecs-task-role.name
  policy_arn = data.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn
}

# Attaches the ecs_redshift_access policy to the ecs_task_role role
# This allows the ecs_task_role role to have the permissions of the ecs_redshift_access policy
resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attach" {
  policy_arn = aws_iam_policy.ecs-redshift-access.arn
  role       = aws_iam_role.ecs-task-role.arn
}

# Attaches the ingest-data-policy policy to the ingest-data-queue queue
# This allows the ingest-data-queue queue to have the permissions of the ingest-data-policy policy
resource "aws_sqs_queue_policy" "ingest-data-queue-policy" {
  # The queue policy is equal to the defined IAM policy
  policy = data.aws_iam_policy_document.ingest-data-policy.json
  # SQS queue URL
  queue_url = aws_sqs_queue.ingest-data-queue.id
}
