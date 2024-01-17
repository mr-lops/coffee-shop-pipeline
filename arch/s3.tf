# Create an S3 bucket
resource "aws_s3_bucket" "ingest-data-bucket" {
  bucket = var.bucket_name

  force_destroy = true
}

# Whenever an object is created in the ingest-data bucket, an event should be sent to the previously created SQS queue.
resource "aws_s3_bucket_notification" "ingest-data-bucket-notification" {
  bucket = aws_s3_bucket.ingest-data-bucket.id

  queue {
    queue_arn = aws_sqs_queue.ingest-data-queue.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.ingest-data-queue-policy]
}
