import os
from dotenv import load_dotenv

# Load from .env if present
load_dotenv(".env")
load_dotenv("config.env")  # Legacy


class Settings:
    # Database
    DATABASE_URL = os.getenv("DATABASE_URL", "mongodb://localhost:27017")
    DATABASE_NAME = os.getenv("DATABASE_NAME", "FileToLink")

    # S3 (legacy / optional fallback)
    S3_ENDPOINT_URL = os.getenv("S3_ENDPOINT_URL")
    S3_REGION = os.getenv("S3_REGION", "auto")
    S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")
    S3_ACCESS_KEY_ID = os.getenv("S3_ACCESS_KEY_ID")
    S3_SECRET_ACCESS_KEY = os.getenv("S3_SECRET_ACCESS_KEY")

    # Telegram storage (primary)
    TELEGRAM_API_ID = os.getenv("TELEGRAM_API_ID", os.getenv("API_ID", ""))
    TELEGRAM_API_HASH = os.getenv("TELEGRAM_API_HASH", os.getenv("API_HASH", ""))
    TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", os.getenv("BOT_TOKEN", ""))
    # User session string (preferred: full read/stream access).
    # Generate once with: python generate_session.py
    TELEGRAM_SESSION_STRING = os.getenv("TELEGRAM_SESSION_STRING", "")
    # Source channel username (e.g. @mymusicchannel) or numeric id
    TELEGRAM_SOURCE_CHANNEL = os.getenv(
        "TELEGRAM_SOURCE_CHANNEL", os.getenv("SOURCE_CHANNEL", "")
    )
    # Optional session name for bot client
    TELEGRAM_SESSION = os.getenv("TELEGRAM_SESSION", "lazyio_bot")

    # Networking / Config
    PORT = int(os.getenv("PORT", 8000))
    BIND_ADDRESS = os.getenv("BIND_ADDRESS", "0.0.0.0")
    WORKERS = int(os.getenv("WORKERS", 4))

    # VPN
    DUCKDNS_DOMAIN = os.getenv("DUCKDNS_DOMAIN")
    DUCKDNS_TOKEN = os.getenv("DUCKDNS_TOKEN")


settings = Settings()
