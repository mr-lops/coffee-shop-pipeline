import boto3
import sqlalchemy
import logging
import os
import json
import urllib.parse
import polars as pl
from math import ceil

logging.basicConfig(format='[%(levelname)s] ; %(message)s', level=logging.INFO, encoding='utf-8')
logger = logging.getLogger(__name__)


def transform_dataset():
    pass


def ingest_redshift():
    pass


if __name__ == "__main__":
    logger.info("Conectando aos serviços")
    sqs_queue_url = os.environ.get('sqs_queue_url')
    sqs = boto3.client('sqs')
    s3_bucket = boto3.client('s3')
    redshift = sqlalchemy.create_engine(
        f'postgresql+psycopg2://{os.environ.get("redshift_user")}:{os.environ.get("redshift_password")}@{
            os.environ.get("redshift_host")}:5439/{os.environ.get("redshift_db")}',
        pool_pre_ping=True
    ).connect()

    while True:
        logger.info("Solicitando mensagem(s) da fila")
        # Solicita uma mensagem da fila SQS
        msg = sqs.receive_message(
            QueueUrl=sqs_queue_url,  # URL da fila SQS
            MaxNumberOfMessages=1,  # Receber apenas uma mensagem por vez
            AttributeNames=['ApproximateReceiveCount'],  # Solicita o atributo 'ApproximateReceiveCount'
            VisibilityTimeout=3600  # Tempo durante o qual a mensagem não será visível para outros consumidores
        ).get('Messages', [])  # Obtém a lista de mensagens (ou lista vazia se não houver mensagens)

        # Se não há mensagem, sai do loop
        if not msg:
            logger.info("Não há mensagem(s)")
            break

        receipt_handle = msg[0].get("ReceiptHandle")  # identificador de recebimento da mensagem
        count_msg = (msg[0].get("Attributes")
                     .get("ApproximateReceiveCount"))  # Contagem de quantas vezes a mensagem foi recebida

        try:
            obj = ""
            sqs.delete_message(QueueUrl=sqs_queue_url,
                               ReceiptHandle=receipt_handle)
            logger.info(f"O objeto {obj} foi processado com sucesso!")

        except Exception as e:
            logger.error(f"Erro ao processar dados {msg}: {e}")
            if int(count_msg) >= 2:
                sqs.delete_message(QueueUrl=sqs_queue_url,
                                   ReceiptHandle=receipt_handle)
                logger.info(f" A mensagem {receipt_handle} foi deletada depois de {count_msg} falhas!")
