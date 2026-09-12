import motor.motor_asyncio
from app.core.config import settings


class Database:
    client: motor.motor_asyncio.AsyncIOMotorClient = None
    db = None

    @classmethod
    def connect(cls):
        if cls.client is None:
            cls.client = motor.motor_asyncio.AsyncIOMotorClient(settings.DATABASE_URL)
            cls.db = cls.client.get_database(settings.DATABASE_NAME)

    @classmethod
    def get_collection(cls, name: str):
        if cls.db is None:
            cls.connect()
        return cls.db.get_collection(name)


# Initialize on import
Database.connect()

# Expose collections directly for convenience, or we can use Database.get_collection inside crud.
songs_collection = Database.get_collection("songs")
playlists_collection = Database.get_collection("playlists")
albums_collection = Database.get_collection("albums")
telegram_state_collection = Database.get_collection("telegram_state")
history_collection = Database.get_collection("history")
