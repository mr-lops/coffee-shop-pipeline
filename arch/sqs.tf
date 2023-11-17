#  cria uma nova fila SQS chamada "ingest-data-queue". A fila será usada para armazenar mensagens relacionadas à ingestão de dados.
resource "aws_sqs_queue" "ingest-data-queue" {
  name = "ingest-data-queue"
}

