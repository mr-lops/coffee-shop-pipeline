# Cria um bucket S3
resource "aws_s3_bucket" "ingest-data-bucket" {
  bucket = "bucket-ingest-21-10-2023"

  force_destroy = true
}

# sempre que um objeto é criado no bucket ingest-data, um evento deve ser enviado para a fila SQS criada anteriormente.
resource "aws_s3_bucket_notification" "ingest-data-bucket-notification" {
  bucket = aws_s3_bucket.ingest-data-bucket.id

  queue {
    queue_arn = aws_sqs_queue.ingest-data-queue.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.ingest-data-queue-policy]
}

