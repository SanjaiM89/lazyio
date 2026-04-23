from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import asyncio
import os

from app.db.connection import Database
from app.db.crud.app_playlists import init_default_playlists
from app.db.crud.songs import get_all_songs
from app.db.crud.likes import get_liked_songs
from app.db.crud.ai_cache import update_ai_cache
from app.services.s3 import init_s3
from app.ai.recommender import audio_recommender
from app.ai.mistral import get_homepage_recommendations

from app.api.routes.websocket import router as ws_router
from app.api.routes.upload import router as upload_router
from app.api.routes.stream import router as stream_router
from app.api.routes.songs import router as songs_router
from app.api.routes.playlists import router as playlists_router
from app.api.routes.youtube import router as youtube_router
from app.api.routes.recommend import router as recommend_router


async def refresh_ai_recommendations():
    """Background task that refreshes AI recommendations every hour"""
    while True:
        try:
            print("[AI] Starting hourly recommendations refresh...")
            all_songs = await get_all_songs()
            if all_songs:
                liked_songs = await get_liked_songs()
                result = await get_homepage_recommendations(all_songs, liked_songs)
                await update_ai_cache(
                    recommendations=result["recommendations"],
                    ai_playlist_name=result["ai_playlist"]["name"],
                    ai_playlist_songs=result["ai_playlist"]["song_ids"],
                )
                print(
                    f"[AI] Cached: {len(result['recommendations'])} recs, playlist '{result['ai_playlist']['name']}'"
                )
            else:
                print("[AI] No songs in library, skipping refresh")
        except Exception as e:
            print(f"[AI] Error refreshing recommendations: {e}")

        await asyncio.sleep(3600)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Connect DB implicitly done by Database.connect() on import
    Database.connect()

    youtube_temp_dir = "temp_uploads/youtube"
    if os.path.exists(youtube_temp_dir):
        import shutil

        try:
            shutil.rmtree(youtube_temp_dir)
            os.makedirs(youtube_temp_dir, exist_ok=True)
            print(f"[STARTUP] Cleaned {youtube_temp_dir} directory")
        except Exception as e:
            print(f"[STARTUP] Failed to clean temp directory: {e}")

    await init_default_playlists()
    print("[STARTUP] Fast init complete - server ready to accept connections")

    async def delayed_init():
        await asyncio.sleep(1)
        try:
            print("[STARTUP] Initializing S3...")
            await init_s3()
        except Exception as e:
            print(f"[STARTUP] Failed to initialize S3: {e}")

        try:
            print("[STARTUP] Loading feature vectors...")
            from app.db.crud.songs import get_all_vectors

            vectors = await get_all_vectors()
            for sid, vec in vectors.items():
                audio_recommender.add_to_index(sid, vec)
            print(f"[STARTUP] Loaded {len(vectors)} vectors into index")
        except Exception as e:
            print(f"[STARTUP] Feature load warning: {e}")

        asyncio.create_task(refresh_ai_recommendations())

    asyncio.create_task(delayed_init())

    yield


app = FastAPI(lifespan=lifespan)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(ws_router)
app.include_router(upload_router)
app.include_router(stream_router)
app.include_router(songs_router)
app.include_router(playlists_router)
app.include_router(youtube_router)
app.include_router(recommend_router)


@app.get("/")
def read_root():
    return {"message": "Lazyio Backend is running"}
