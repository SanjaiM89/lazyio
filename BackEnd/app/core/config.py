import os
from dotenv import load_dotenv

# Load from .env if present
load_dotenv(".env")
load_dotenv("config.env")  # Legacy


class Settings:
    # Database
    DATABASE_URL = os.getenv("DATABASE_URL", "mongodb://localhost:27017")
    DATABASE_NAME = os.getenv("DATABASE_NAME", "FileToLink")

    # S3
    S3_ENDPOINT_URL = os.getenv("S3_ENDPOINT_URL")
    S3_REGION = os.getenv("S3_REGION", "auto")
    S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")
    S3_ACCESS_KEY_ID = os.getenv("S3_ACCESS_KEY_ID")
    S3_SECRET_ACCESS_KEY = os.getenv("S3_SECRET_ACCESS_KEY")

    # Networking / Config
    PORT = int(os.getenv("PORT", 8000))
    BIND_ADDRESS = os.getenv("BIND_ADDRESS", "0.0.0.0")
    WORKERS = int(os.getenv("WORKERS", 4))

    # VPN
    DUCKDNS_DOMAIN = os.getenv("DUCKDNS_DOMAIN")
    DUCKDNS_TOKEN = os.getenv("DUCKDNS_TOKEN")


settings = Settings()
