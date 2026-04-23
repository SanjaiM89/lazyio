from app.db.connection import Database
from datetime import datetime

ai_cache_collection = Database.get_collection("ai_cache")


async def get_ai_cache(cache_key: str = "home_recommendations") -> dict:
    doc = await ai_cache_collection.find_one({"key": cache_key})
    if doc:
        return {
            "key": doc.get("key"),
            "recommendations": doc.get("recommendations", []),
            "ai_playlist_name": doc.get("ai_playlist_name", "AI Mix"),
            "ai_playlist_songs": doc.get("ai_playlist_songs", []),
            "updated_at": doc.get("updated_at"),
        }
    return None


async def update_ai_cache(
    recommendations: list,
    ai_playlist_name: str,
    ai_playlist_songs: list,
    cache_key: str = "home_recommendations",
):
    await ai_cache_collection.update_one(
        {"key": cache_key},
        {
            "$set": {
                "key": cache_key,
                "recommendations": recommendations,
                "ai_playlist_name": ai_playlist_name,
                "ai_playlist_songs": ai_playlist_songs,
                "updated_at": datetime.utcnow(),
            }
        },
        upsert=True,
    )
