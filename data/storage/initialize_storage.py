# Script to initialize MinIO bucket and PostgreSQL tables
import boto3
import botocore
import psycopg2
import yaml

with open('config/settings.yaml') as f:
    config = yaml.safe_load(f)

# Setup MinIO bucket
minio_cfg = config['data']['storage']['minio']
s3 = boto3.resource('s3',
                    endpoint_url=minio_cfg['endpoint'],
                    aws_access_key_id=minio_cfg['access_key'],
                    aws_secret_access_key=minio_cfg['secret_key'])

bucket_name = minio_cfg['bucket']
try:
    s3.meta.client.head_bucket(Bucket=bucket_name)
    print(f"Bucket {bucket_name} already exists.")
except botocore.exceptions.ClientError:
    s3.create_bucket(Bucket=bucket_name)
    print(f"Created bucket: {bucket_name}")

# Setup PostgreSQL tables
db_cfg = config['data']['database']['postgres']
conn = psycopg2.connect(
    host=db_cfg['host'],
    dbname=db_cfg['dbname'],
    user=db_cfg['user'],
    password=db_cfg['password'],
    port=db_cfg['port']
)
cur = conn.cursor()
cur.execute("""
CREATE TABLE IF NOT EXISTS experiments (
    id SERIAL PRIMARY KEY,
    experiment_name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
""")
conn.commit()
cur.close()
conn.close()
print("Initialized PostgreSQL database.")
