# Create a new SQS queue named "ingest-data-queue". The queue will be used to store messages related to data ingestion.
resource "aws_sqs_queue" "ingest-data-queue" {
  name = "ingest-data-queue"
}
