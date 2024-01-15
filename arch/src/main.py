import boto3
import sqlalchemy
from sqlalchemy.sql import text
import logging
import os
import json
import urllib.parse
import polars as pl

logging.basicConfig(format='[%(levelname)s] ; %(message)s', level=logging.INFO, encoding='utf-8')
logger = logging.getLogger(__name__)


def transform_dataset(json_file) -> pl.dataframe:
    data = pl.read_ndjson(json_file)
    return data


def ingest_redshift(data, redshift_conn) -> None:
    with open("database/create_table.sql") as file:
        query = text(file.read())
        redshift_conn.execute(query)

    values = ([v[0] for v in data.to_dict(as_series=False).values()])

    insert = f"""
             INSERT INTO Sales_Coffee (transaction_id, transaction_date, transaction_time, transaction_qty, store_id,
                                        store_location, product_id, unit_price, product_category, 
                                        product_type, product_detail)
             VALUES {values}
             """
    logger.info(f"Running command {insert}")
    redshift_conn.execute(insert)
    return None


if __name__ == "__main__":
    logger.info("Connecting to services")
    sqs_queue_url = os.environ.get('sqs_queue_url')
    sqs = boto3.client('sqs')
    s3_bucket = boto3.client('s3')
    redshift = sqlalchemy.create_engine(
        f'postgresql+psycopg2://{os.environ.get("redshift_user")}:{os.environ.get("redshift_password")}@{
            os.environ.get("redshift_host")}:5439/{os.environ.get("redshift_db")}',
        pool_pre_ping=True
    ).connect()

    while True:
        logger.info("Requesting message in queue")
        # Requesting a message in SQS queue
        msg = sqs.receive_message(
            QueueUrl=sqs_queue_url,  # SQS queue URL
            MaxNumberOfMessages=1,  # Receive only one message at a time
            AttributeNames=['ApproximateReceiveCount'],  # Request 'ApproximateReceiveCount' attribute
            VisibilityTimeout=3600  # Time during the message will not be visible to other consumers
        ).get('Messages', [])  # Gets the list of messages (or empty list if there are no messages)

        # If there is no message, exit the loop
        if not msg:
            logger.info("There are no messages")
            break

        receipt_handle = msg[0].get("ReceiptHandle")  # Message receipt identifier
        count_msg = (msg[0].get("Attributes")
                     .get("ApproximateReceiveCount"))  # Count of how many times the message was received

        try:
            logger.info("Transforming data")
            queue_message = json.loads(msg[0].get('Body'))
            bucket_name = queue_message.get('Records')[0]['s3']['bucket']['name']
            obj = urllib.parse.unquote_plus(queue_message['Records'][0]['s3']['object']['key'], encoding='utf-8')
            file_json = s3_bucket.download_file(Bucket=bucket_name, Key=obj, Filename="./data.json")
            dataset = transform_dataset(file_json)

            logger.info("Ingesting data in Redshift")
            ingest_redshift(dataset, redshift)

            sqs.delete_message(QueueUrl=sqs_queue_url,
                               ReceiptHandle=receipt_handle)
            logger.info(f"Successfully processed and ingested data from {obj}.")

        except Exception as e:
            logger.error(f"Error processing data from {msg}: {e}")
            if int(count_msg) >= 2:
                sqs.delete_message(QueueUrl=sqs_queue_url,
                                   ReceiptHandle=receipt_handle)
                logger.info(f"Message with receipt handle {receipt_handle} has been deleted after {count_msg} failures.")
