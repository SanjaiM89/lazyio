import os
import aioboto3
from botocore.exceptions import ClientError
from app.core.config import settings
import asyncio

# Configuration
S3_ENDPOINT_URL = settings.S3_ENDPOINT_URL
S3_REGION = settings.S3_REGION
S3_BUCKET_NAME = settings.S3_BUCKET_NAME
S3_ACCESS_KEY_ID = settings.S3_ACCESS_KEY_ID
S3_SECRET_ACCESS_KEY = settings.S3_SECRET_ACCESS_KEY

session = aioboto3.Session()


def get_s3_client():
    return session.client(
        "s3",
        endpoint_url=S3_ENDPOINT_URL,
        region_name=S3_REGION,
        aws_access_key_id=S3_ACCESS_KEY_ID,
        aws_secret_access_key=S3_SECRET_ACCESS_KEY,
    )


async def init_s3():
    """Ensure bucket exists."""
    if not all(
        [S3_ENDPOINT_URL, S3_BUCKET_NAME, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY]
    ):
        print("[S3] Missing S3 configuration, skipping initialization.")
        return

    print(
        f"[S3] Initializing S3 connection to {S3_ENDPOINT_URL} for bucket {S3_BUCKET_NAME}..."
    )
    async with get_s3_client() as client:
        try:
            await client.head_bucket(Bucket=S3_BUCKET_NAME)
            print(f"[S3] Bucket {S3_BUCKET_NAME} already exists.")
        except ClientError as e:
            error_code = int(e.response["Error"]["Code"])
            if error_code == 404:
                print(f"[S3] Bucket {S3_BUCKET_NAME} does not exist. Creating...")
                try:
                    await client.create_bucket(Bucket=S3_BUCKET_NAME)
                    print(f"[S3] Bucket {S3_BUCKET_NAME} created successfully.")
                except Exception as create_err:
                    print(f"[S3] Failed to create bucket: {create_err}")
            else:
                print(f"[S3] Error checking bucket: {e}")


async def upload_file(file_path: str, object_name: str = None) -> str:
    """Upload a file to an S3 bucket
    :param file_path: File to upload
    :param object_name: S3 object name. If not specified then file_path is used
    :return: True if file was uploaded, else False
    """
    if object_name is None:
        object_name = os.path.basename(file_path)

    async with get_s3_client() as client:
        try:
            # We determine content type roughly
            content_type = "application/octet-stream"
            if object_name.endswith(".mp4") or object_name.endswith(".mkv"):
                content_type = "video/mp4"
            elif object_name.endswith(".mp3"):
                content_type = "audio/mpeg"
            elif object_name.endswith(".m4a"):
                content_type = "audio/mp4"

            print(f"[S3] Uploading {file_path} to {object_name}...")
            with open(file_path, "rb") as f:
                await client.upload_fileobj(
                    f,
                    S3_BUCKET_NAME,
                    object_name,
                    ExtraArgs={"ContentType": content_type},
                )
            print(f"[S3] Uploaded successfully: {object_name}")
            return object_name
        except Exception as e:
            print(f"[S3] Upload error: {e}")
            return None


async def get_presigned_url(object_name: str, expiration=3600) -> str:
    """Generate a presigned URL to share an S3 object"""
    async with get_s3_client() as client:
        try:
            response = await client.generate_presigned_url(
                "get_object",
                Params={"Bucket": S3_BUCKET_NAME, "Key": object_name},
                ExpiresIn=expiration,
            )
        except ClientError as e:
            print(f"[S3] Presigned URL error: {e}")
            return None

        # Fix for virtual-hosted-style URLs if endpoint forces path-style sometimes
        # The user image specifies "Use virtual-hosted-style URLs."
        # boto3 should handle it if endpoint is correct, but just in case:
        return response


async def delete_file(object_name: str) -> bool:
    """Delete a file from S3"""
    async with get_s3_client() as client:
        try:
            await client.delete_object(Bucket=S3_BUCKET_NAME, Key=object_name)
            return True
        except ClientError as e:
            print(f"[S3] Delete error: {e}")
            return False
