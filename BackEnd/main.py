from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks, Request, WebSocket, WebSocketDisconnect
from typing import List
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import os
from dotenv import load_dotenv

# Load config.env explicitly for standalone execution
if os.path.exists("config.env"):
    load_dotenv("config.env")

import shutil
import asyncio

# Local imports
from database import (
    init_db, add_song, get_all_songs, get_song_by_id, search_songs,
    delete_song, get_songs_paginated,
    create_playlist, get_playlists, get_playlist_by_id,
    add_song_to_playlist, remove_song_from_playlist, delete_playlist,
    record_play, get_recently_played,
    get_ai_cache, update_ai_cache,
    like_song, dislike_song, get_like_status, get_liked_songs, get_recommendations,
    get_all_vectors, update_song_features
)
from telegram_client import tg_client, FileNotFound
from metadata import extract_metadata
from mistral_agent import get_music_recommendations, get_homepage_recommendations
from audio_recommender import audio_recommender

# Background task for hourly AI refresh
async def refresh_ai_recommendations():
    """Background task that refreshes AI recommendations every hour"""
    while True:
        try:
            print("[AI] Starting hourly recommendations refresh...")
            all_songs = await get_all_songs()
            if all_songs:
                # Fetch liked songs for personalization
                liked_songs = await get_liked_songs()
                result = await get_homepage_recommendations(all_songs, liked_songs)
                await update_ai_cache(
                    recommendations=result["recommendations"],
                    ai_playlist_name=result["ai_playlist"]["name"],
                    ai_playlist_songs=result["ai_playlist"]["song_ids"]
                )
                print(f"[AI] Cached: {len(result['recommendations'])} recs, playlist '{result['ai_playlist']['name']}'")
            else:
                print("[AI] No songs in library, skipping refresh")
        except Exception as e:
            print(f"[AI] Error refreshing recommendations: {e}")
        
        # Sleep for 1 hour
        await asyncio.sleep(3600)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # === FAST STARTUP - Bind port first ===
    # Only do minimal init here so Render detects port quickly
    await init_db()
    
    # Clean up temp dirs
    youtube_temp_dir = os.path.join(TEMP_DIR, "youtube")
    if os.path.exists(youtube_temp_dir):
        import shutil
        try:
            shutil.rmtree(youtube_temp_dir)
            os.makedirs(youtube_temp_dir, exist_ok=True)
            print(f"[STARTUP] Cleaned temp_uploads/youtube directory")
        except Exception as e:
            print(f"[STARTUP] Failed to clean temp directory: {e}")
    
    # Initialize default playlists (fast)
    await init_default_playlists()
    
    print("[STARTUP] Fast init complete - server ready to accept connections")
    
    # === BACKGROUND INITIALIZATION ===
    # Start heavy tasks in background AFTER server is listening
    async def delayed_init():
        """Run heavy initialization after server starts"""
        await asyncio.sleep(1)  # Give server time to bind port
        
        # Start Telegram client
        try:
            print("[STARTUP] Starting Telegram client...")
            await tg_client.start()
            
            # Initialize Telegram Notifier for VPN auto-recovery
            from telegram_notifier import init_notifier
            init_notifier(tg_client)
            print("[STARTUP] Telegram client ready")
        except Exception as e:
            print(f"[STARTUP] Failed to start Telegram Client: {e}")
        
        # Load Audio Recommender Index
        try:
            print("[STARTUP] Loading feature vectors...")
            vectors = await get_all_vectors()
            for sid, vec in vectors.items():
                audio_recommender.add_to_index(sid, vec)
            print(f"[STARTUP] Loaded {len(vectors)} vectors into index")
        except Exception as e:
            print(f"[STARTUP] Failed to load vectors: {e}")
    
    # Start background init task
    init_task = asyncio.create_task(delayed_init())
    
    # Start background AI refresh task
    ai_task = asyncio.create_task(refresh_ai_recommendations())
    
    yield
    
    # Shutdown
    ai_task.cancel()
    init_task.cancel()
    await tg_client.stop()

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allow ALL origins for mobile/web/development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Range", "Accept-Ranges", "Content-Length", "Content-Type"],
)

TEMP_DIR = "temp_uploads"
os.makedirs(TEMP_DIR, exist_ok=True)

# --- WebSocket Manager ---
import json

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                pass

    async def broadcast_json(self, data: dict):
        """Broadcast JSON data to all connected clients"""
        message = json.dumps(data)
        await self.broadcast(message)

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive by waiting for messages (even if we ignore them)
            # This prevents the handler from exiting and closing the socket
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        print(f"WebSocket error: {e}")
        try:
            manager.disconnect(websocket)
        except:
            pass

# Helper to notify clients
async def notify_update(event_type: str = "song_added", data: dict = None):
    """Broadcast an event to all WebSocket clients"""
    payload = {"event": event_type}
    if data:
        payload["data"] = data
    await manager.broadcast_json(payload)

async def broadcast_task_update(task_id: str):
    """Broadcast a task update to all WebSocket clients"""
    from vidssave_downloader import get_vidssave_task
    task = get_vidssave_task(task_id)
    if task:
        task_dict = {
            "task_id": task.task_id,
            "url": task.url,
            "status": task.status.value,
            "progress": task.progress,
            "title": task.title,
            "artist": task.artist,
            "thumbnail": task.thumbnail,
            "duration": task.duration,
            "error": task.error or "",
            "speed": getattr(task, 'speed', "0 B/s"),
            "eta": getattr(task, 'eta', "--:--"),
            "phase": getattr(task, 'phase', "downloading"),
            "quality": "320",
            "media_type": "audio"
        }
        await notify_update("task_update", task_dict)


# ==================== Connection Info API ====================
# Allows mobile app to fetch current server IP/Port from MongoDB

@app.get("/api/connection-info")
async def get_connection_info():
    """
    Get current server connection info (IP and Port) from MongoDB.
    This is updated by vpn_manager.py when VPN connects.
    """
    try:
        settings = db["settings"]
        doc = settings.find_one({"_id": "connection_info"})
        if doc:
            return {
                "ip": doc.get("ip"),
                "port": doc.get("port"),
                "updated_at": doc.get("updated_at"),
                "domain": "lazyio.duckdns.org"  # DuckDNS domain
            }
        return {"ip": None, "port": None, "domain": "lazyio.duckdns.org"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

from pydantic import BaseModel as PortBaseModel

class PortUpdateRequest(PortBaseModel):
    port: str

@app.post("/api/connection-info/port")
async def update_port(request: PortUpdateRequest):
    """
    Manually update the port in MongoDB.
    Useful if user needs to set it from mobile app.
    """
    try:
        settings = db["settings"]
        settings.update_one(
            {"_id": "connection_info"},
            {"$set": {"port": request.port}},
            upsert=True
        )
        return {"success": True, "port": request.port}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== YouTube Cookies Upload ====================

@app.post("/api/settings/cookies")
async def upload_cookies(file: UploadFile = File(...)):
    """
    Upload a cookies.txt file for YouTube downloads.
    This file should be exported from browser using extensions like 'Get cookies.txt LOCALLY'.
    """
    COOKIES_FILE = os.path.join(os.path.dirname(__file__), "cookies.txt")
    
    if not file.filename.endswith('.txt'):
        raise HTTPException(status_code=400, detail="File must be a .txt file")
    
    try:
        # Save the uploaded cookies file
        with open(COOKIES_FILE, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Verify it's a valid Netscape cookies format (basic check)
        with open(COOKIES_FILE, "r") as f:
            first_line = f.readline()
            if "Netscape" not in first_line and not first_line.startswith("#"):
                # Still valid if it starts with domain entries
                if not first_line.startswith("."):
                    os.remove(COOKIES_FILE)
                    raise HTTPException(status_code=400, detail="Invalid cookies.txt format. Use Netscape format.")
        
        return {"success": True, "message": "Cookies uploaded successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/settings/cookies")
async def get_cookies_status():
    """Check if cookies.txt file exists on server"""
    COOKIES_FILE = os.path.join(os.path.dirname(__file__), "cookies.txt")
    
    if os.path.exists(COOKIES_FILE):
        file_size = os.path.getsize(COOKIES_FILE)
        mod_time = os.path.getmtime(COOKIES_FILE)
        from datetime import datetime
        return {
            "exists": True,
            "size": file_size,
            "updated_at": datetime.fromtimestamp(mod_time).isoformat()
        }
    return {"exists": False}


@app.delete("/api/settings/cookies")
async def delete_cookies():
    """Delete the cookies.txt file"""
    COOKIES_FILE = os.path.join(os.path.dirname(__file__), "cookies.txt")
    
    if os.path.exists(COOKIES_FILE):
        os.remove(COOKIES_FILE)
        return {"success": True, "message": "Cookies file deleted"}
    return {"success": False, "message": "No cookies file found"}


@app.post("/api/upload")
async def upload_files(background_tasks: BackgroundTasks, files: list[UploadFile] = File(...)):
    """
    Uploads files to server temp, extracts metadata, uploads to Telegram,
    saves to DB, then cleans up.
    For video files: also extracts audio and uploads as separate stream.
    Broadcasts progress via WebSocket.
    """
    # ... (imports inside function if needed, or rely on global)
    from audio_extractor import extract_audio_from_video, cleanup_extracted_file
    
    VIDEO_EXTENSIONS = ['.mp4', '.mkv', '.webm', '.avi', '.mov']
    uploaded_songs = []
    total_files = len(files)
    loop = asyncio.get_event_loop()

    async def process_file(file_path, file_name, file_index):
        try:
            # Check if it's a video file
            is_video = any(file_name.lower().endswith(ext) for ext in VIDEO_EXTENSIONS)
            
            # Broadcast: Extracting metadata
            await notify_update("upload_progress", {
                "file_name": file_name,
                "file_index": file_index,
                "total_files": total_files,
                "stage": "metadata",
                "message": f"Extracting metadata from {file_name}..."
            })
            
            # Extract Metadata
            meta = await extract_metadata(file_path)
            
            # Broadcast: Uploading to Telegram
            await notify_update("upload_progress", {
                "file_name": file_name,
                "file_index": file_index,
                "total_files": total_files,
                "stage": "telegram",
                "message": f"Uploading {file_name} to Telegram..."
            })
            
            # Upload main file to Telegram (video or audio)
            tg_msg = await tg_client.upload_file(file_path)
            if not tg_msg:
                await notify_update("upload_progress", {
                    "file_name": file_name,
                    "file_index": file_index,
                    "total_files": total_files,
                    "stage": "error",
                    "message": f"Failed to upload {file_name} to Telegram"
                })
                if os.path.exists(file_path):
                    os.remove(file_path)
                return
                
            telegram_ref = str(tg_msg.id)
            
            # For video files, also extract and upload audio
            audio_telegram_id = None
            video_telegram_id = None
            
            if is_video:
                video_telegram_id = telegram_ref
                
                # Broadcast: Extracting audio
                await notify_update("upload_progress", {
                    "file_name": file_name,
                    "file_index": file_index,
                    "total_files": total_files,
                    "stage": "extracting_audio",
                    "message": f"Extracting audio from {file_name}..."
                })
                
                # Extract audio from video
                audio_path = await extract_audio_from_video(file_path)
                if audio_path:
                    audio_msg = await tg_client.upload_file(audio_path)
                    if audio_msg:
                        audio_telegram_id = str(audio_msg.id)
                        print(f"[UPLOAD] Audio extracted and uploaded: {audio_telegram_id}")
                    cleanup_extracted_file(audio_path)
            else:
                audio_telegram_id = telegram_ref
            
            # Broadcast: Saving to database
            await notify_update("upload_progress", {
                "file_name": file_name,
                "file_index": file_index,
                "total_files": total_files,
                "stage": "database",
                "message": f"Saving {file_name} to database..."
            })
            
            # Save to DB with both IDs
            song_id = await add_song(
                telegram_file_id=audio_telegram_id or video_telegram_id,
                audio_telegram_id=audio_telegram_id,
                video_telegram_id=video_telegram_id,
                has_video=is_video,
                title=meta.get("title"),
                artist=meta.get("artist"),
                album=meta.get("album"),
                duration=meta.get("duration"),
                cover_art=meta.get("cover_art"),
                file_name=file_name,
                file_size=os.path.getsize(file_path)
            )
            
            # Broadcast: File complete
            await notify_update("upload_progress", {
                "file_name": file_name,
                "file_index": file_index,
                "total_files": total_files,
                "stage": "complete",
                "message": f"Upload complete: {meta.get('title', file_name)}"
            })
            
        except Exception as e:
            print(f"[UPLOAD] Error processing {file_name}: {e}")
            await notify_update("upload_progress", {
                "file_name": file_name,
                "file_index": file_index,
                "total_files": total_files,
                "stage": "error",
                "message": f"Error: {str(e)}"
            })
        finally:
            # Cleanup
            if os.path.exists(file_path):
                os.remove(file_path)
                
        # Send overall completion if this was the last file? 
        # Ideally we track all tasks, but simplified:
        await notify_update("upload_complete", {"count": 1}) # Simple notification per file

    for i, file in enumerate(files):
        file_name = file.filename or f"unknown_{i}"
        temp_path = os.path.join(TEMP_DIR, file_name)
        
        try:
            # Broadcast: Starting upload for this file
            await notify_update("upload_progress", {
                "file_name": file_name,
                "file_index": i,
                "total_files": total_files,
                "stage": "saving",
                "message": f"Saving {file_name}..."
            })
            
            # Non-blocking file save
            def _save_file():
                with open(temp_path, "wb") as buffer:
                    shutil.copyfileobj(file.file, buffer)
            
            await loop.run_in_executor(None, _save_file)
            
            # Offload processing to background task
            background_tasks.add_task(process_file, temp_path, file_name, i)
            uploaded_songs.append({"file_name": file_name, "status": "processing"})
            
        except Exception as e:
            print(f"[UPLOAD] Error saving {file_name}: {e}")
            await notify_update("upload_progress", {
                "file_name": file_name,
                "file_index": i,
                "stage": "error",
                "message": f"Error saving file: {str(e)}"
            })
    
    # Return immediately while processing happens in background
    return {"status": "success", "message": "Uploads started in background", "files": uploaded_songs}

@app.get("/api/songs")
async def list_songs():
    return await get_all_songs()

# ... (Keep your existing imports and setup) ...

@app.get("/api/stream/{song_id}")
async def stream_song(song_id: str, request: Request, type: str = None, quality: str = "original"):
    """
    Stream a song with optimized Range support and Nginx bypass.
    """
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    
    # Resolve correct Telegram ID
    if type == "audio":
        msg_id_str = song.get("audio_telegram_id") or song.get("telegram_file_id")
    elif type == "video":
        msg_id_str = song.get("video_telegram_id")
        if not msg_id_str:
            raise HTTPException(status_code=404, detail="Video stream not available")
    else:
        msg_id_str = song.get("telegram_file_id")
    
    if not msg_id_str:
         raise HTTPException(status_code=404, detail="Song has no Telegram File ID")

    msg_id = int(msg_id_str)
    print(f"[STREAM] Request for {song_id} -> Telegram Msg ID: {msg_id} (Type: {type})")

    try:
        # Get file info
        file_info = await tg_client.get_file_info(msg_id)
        if not file_info:
             print(f"[STREAM] get_file_info returned None for {msg_id}")
             raise FileNotFound("File info unavailable")
             
        file_size = file_info["file_size"]
        mime_type = file_info["mime_type"]
        
        # Parse Range Header (Standard HTTP 206)
        range_header = request.headers.get("Range")
        start = 0
        end = file_size - 1
        
        if range_header:
            try:
                # Format: bytes=0-1024
                range_str = range_header.replace("bytes=", "")
                parts = range_str.split("-")
                start = int(parts[0]) if parts[0] else 0
                if len(parts) > 1 and parts[1]:
                    end = int(parts[1])
            except ValueError:
                pass
        
        # Ensure end is valid
        if end >= file_size: 
            end = file_size - 1
            
        content_length = end - start + 1
        
        # Industry Standard Headers for Streaming
        headers = {
            "Content-Range": f"bytes {start}-{end}/{file_size}",
            "Accept-Ranges": "bytes",
            "Content-Length": str(content_length),
            "Content-Type": mime_type,
            "Connection": "keep-alive",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            # CRITICAL: Tells Nginx/Proxies NOT to buffer chunks
            "X-Accel-Buffering": "no", 
        }
        
        return StreamingResponse(
            tg_client.stream_file(msg_id, offset=start, limit=content_length),
            status_code=206,
            headers=headers,
            media_type=mime_type
        )

    except FileNotFound:
        print(f"[Stream] 404 Error: File {msg_id} not found in Telegram channel.")
        raise HTTPException(status_code=404, detail="File lost in Telegram. Please re-upload.")
    except Exception as e:
        print(f"[Stream] 500 Error for song {song_id} (msg={msg_id}): {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Streaming error: {str(e)}")



@app.post("/api/recommend")
async def recommend(current_song_id: str, history_ids: list[str]):
    """
    Get recommendations based on current song and history.
    """
    current_song = await get_song_by_id(current_song_id)
    
    history = []
    for hid in history_ids:
        s = await get_song_by_id(hid)
        if s:
            history.append(s)
    
    if not current_song:
        return {"recommendations": []}
        
    recs = await get_music_recommendations(current_song, history)
    
    # In a real app, we would match these strings to songs in our DB or search Youtube/Spotify
    # For now, we return the strings or try to find matches in our DB
    
    db_matches = []
    for rec in recs:
        # Simple fuzzy search in our DB
        # Assuming rec format "Title - Artist"
        parts = rec.split("-")
        if len(parts) >= 1:
            query = parts[0].strip()
            matches = await search_songs(query)
            if matches:
                db_matches.extend(matches)
                
    # remove duplicates
    unique_matches = {v['id']:v for v in db_matches}.values()
    
    
    return {
        "mistral_suggestions": recs,
        "playable_matches": list(unique_matches)
    }


@app.post("/api/admin/scan-audio-features")
async def api_scan_audio_features(background_tasks: BackgroundTasks):
    """Trigger background scan of all songs to extract audio features"""
    
    async def _scan_task():
        print("[SCAN] Starting library audio analysis...")
        
        # 0. Check dependencies
        if not audio_recommender.DEPENDENCIES_AVAILABLE:
             print("[SCAN] Skipped: Dependencies (essentia/faiss) not installed.")
             return
             
        # 1. Get all songs
        all_songs = await get_all_songs()
        print(f"[SCAN] Found {len(all_songs)} songs to check.")
        
        count = 0
        for song in all_songs:
            # Need local file path. Note: Telegram files might not be local.
            # Only process if we have a local file?
            # Creating a temp file from telegram DL might be needed.
            # For now, let's assume we might have some local files or skip.
            # Wait, `upload_files` saves to TEMP_DIR and then deletes.
            # We don't keep local files!
            # We need to DOWNLOAD the file to process it if it's missing.
            pass
            # TODO: Implementation for streaming/downloading for analysis
            # For now, this placeholder handles the architecture. 
            # In a real deployed version without local storage, we'd need to download -> analyze -> delete.
            
    # background_tasks.add_task(_scan_task)
    return {"status": "started", "message": "Scan functionality requires persistent local storage or temporary download logic."}


@app.get("/api/recommend/similar/{song_id}")
async def api_recommend_similar(song_id: str, limit: int = 10):
    """Get content-based similar songs using Vector Search"""
    similar_ids = audio_recommender.find_similar(song_id, limit)
    
    songs = []
    for sid in similar_ids:
        s = await get_song_by_id(sid)
        if s:
            songs.append(s)
            
    return {"similar_songs": songs}


# ==================== Like/Dislike API ====================

@app.post("/api/songs/{song_id}/like")
async def api_like_song(song_id: str):
    """Like a song"""
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    await like_song(song_id)
    return {"status": "liked", "song_id": song_id}


@app.post("/api/songs/{song_id}/dislike")
async def api_dislike_song(song_id: str):
    """Dislike a song"""
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    await dislike_song(song_id)
    return {"status": "disliked", "song_id": song_id}


@app.get("/api/songs/{song_id}/like-status")
async def api_get_like_status(song_id: str):
    """Get like status for a song. Returns {liked: true/false/null}"""
    status = await get_like_status(song_id)
    return status


@app.get("/api/recommendations")
async def api_get_recommendations(limit: int = 10):
    """Get personalized recommendations based on likes/dislikes"""
    recs = await get_recommendations(limit)
    return {"recommendations": recs}


@app.get("/api/liked-songs")
async def api_get_liked_songs():
    """Get all liked songs"""
    songs = await get_liked_songs()
    return {"songs": songs}


@app.get("/api/upcoming-queue/{song_id}")
async def api_get_upcoming_queue(song_id: str):
    """
    Get LLM-generated upcoming queue based on current song and liked songs.
    Returns songs from library that match AI suggestions.
    """
    current_song = await get_song_by_id(song_id)
    if not current_song:
        raise HTTPException(status_code=404, detail="Song not found")
    
    # Get liked songs for context
    liked_songs = await get_liked_songs()
    all_songs = await get_all_songs()
    
    # Build history from liked songs or all songs
    history = liked_songs[:5] if liked_songs else all_songs[:5]
    
    # Get AI recommendations
    ai_suggestions = await get_music_recommendations(current_song, history)
    
    # Match suggestions to songs in library
    matches = []
    for suggestion in ai_suggestions:
        # Try to find matching song in library
        parts = suggestion.split(" - ")
        if len(parts) >= 1:
            query = parts[0].strip()
            found = await search_songs(query)
            # Filter out current song and add unique matches
            for s in found:
                if s["id"] != song_id and s["id"] not in [m["id"] for m in matches]:
                    matches.append(s)
                    break
    
    # If we don't have enough matches, fill with liked songs then random
    if len(matches) < 5:
        liked_ids = {m["id"] for m in matches}
        liked_ids.add(song_id)
        for s in liked_songs:
            if s["id"] not in liked_ids:
                matches.append(s)
                liked_ids.add(s["id"])
            if len(matches) >= 10:
                break
    
    return {
        "ai_suggestions": ai_suggestions,  # Raw LLM suggestions
        "queue": matches[:10]  # Matched songs from library
    }


# ==================== Persistent AI Queue API ====================
from database import (
    get_ai_queue, save_ai_queue, mark_song_played as db_mark_played,
    get_queue_songs, refill_queue_if_needed, clear_played_queue
)


@app.get("/api/ai-queue")
async def api_get_ai_queue():
    """Get current AI queue from MongoDB (persistent)"""
    # Ensure minimum 10 songs
    await refill_queue_if_needed(min_songs=10)
    
    queue_data = await get_ai_queue()
    songs = await get_queue_songs()
    
    return {
        "songs": songs,
        "played_count": len(queue_data["played_ids"]),
        "created_at": str(queue_data["created_at"]) if queue_data["created_at"] else None,
        "updated_at": str(queue_data["updated_at"]) if queue_data["updated_at"] else None,
    }


@app.post("/api/ai-queue/refresh")
async def api_refresh_ai_queue():
    """Regenerate AI queue using LLM and save to MongoDB"""
    # Get liked songs for personalization
    liked_songs = await get_liked_songs()
    all_songs = await get_all_songs()
    
    if not all_songs:
        return {"status": "error", "message": "No songs in library"}
    
    # Build history from liked songs
    history = liked_songs[:5] if liked_songs else all_songs[:5]
    import random
    sample_song = random.choice(liked_songs) if liked_songs else random.choice(all_songs)
    
    # Get AI suggestions
    ai_suggestions = await get_music_recommendations(sample_song, history)
    
    # Match to library songs
    matched_ids = []
    for suggestion in ai_suggestions:
        parts = suggestion.split(" - ")
        if parts:
            query = parts[0].strip()
            found = await search_songs(query)
            for s in found:
                if s["id"] not in matched_ids:
                    matched_ids.append(s["id"])
                    break
    
    # Add liked songs
    for s in liked_songs:
        if s["id"] not in matched_ids:
            matched_ids.append(s["id"])
        if len(matched_ids) >= 15:
            break
    
    # Fill remaining with random songs
    if len(matched_ids) < 10:
        random.shuffle(all_songs)
        for s in all_songs:
            if s["id"] not in matched_ids:
                matched_ids.append(s["id"])
            if len(matched_ids) >= 15:
                break
    
    # Clear played and save new queue
    await clear_played_queue()
    await save_ai_queue(matched_ids)
    
    # Get full song objects
    songs = await get_queue_songs()
    
    return {
        "status": "refreshed",
        "count": len(songs),
        "songs": songs,
        "ai_suggestions": ai_suggestions,
    }


@app.post("/api/ai-queue/mark-played/{song_id}")
async def api_mark_song_played(song_id: str):
    """Mark a song as played (removes from queue)"""
    await db_mark_played(song_id)
    await refill_queue_if_needed(min_songs=10)
    return {"status": "marked", "song_id": song_id}


from pydantic import BaseModel as PydanticBaseModel

class SignalRequest(PydanticBaseModel):
    signal_type: str  # "listen", "skip", "like", "dislike"
    duration_seconds: int = 0  # For listen signals


@app.post("/api/ai-queue/signal/{song_id}")
async def api_queue_signal(song_id: str, request: SignalRequest):
    """
    Report user behavior signal for smart queue updates.
    - listen: played > 60 seconds (positive signal)
    - skip: skipped before 60 seconds (negative signal)  
    - like/dislike: explicit preference
    """
    signal_type = request.signal_type
    duration = request.duration_seconds
    
    song = await get_song_by_id(song_id)
    if not song:
        return {"status": "error", "message": "Song not found"}
    
    if signal_type == "listen" and duration >= 60:
        # Positive signal: mark as played and potentially add similar
        await db_mark_played(song_id)
        # Could enhance: add similar songs to queue based on this
        
    elif signal_type == "skip":
        # Negative signal: just mark as played to remove from queue
        await db_mark_played(song_id)
        
    elif signal_type == "like":
        # Already handled by like API, but refill queue
        await like_song(song_id)
        
    elif signal_type == "dislike":
        # Remove from queue and don't suggest similar
        await dislike_song(song_id)
        await db_mark_played(song_id)
    
    # Ensure queue stays filled
    await refill_queue_if_needed(min_songs=10)
    
    return {"status": "processed", "signal": signal_type, "song_id": song_id}


# ==================== App Playlists API ====================
from database import (
    get_app_playlists, create_app_playlist, get_playlist_with_songs, init_default_playlists
)
from pydantic import BaseModel

@app.get("/api/app-playlists")
async def api_get_app_playlists():
    """Get all app playlists"""
    return await get_app_playlists()

@app.get("/api/app-playlists/{playlist_id}")
async def api_get_app_playlist(playlist_id: str):
    """Get specific playlist with full song details"""
    playlist = await get_playlist_with_songs(playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    return playlist

class GeneratePlaylistRequest(BaseModel):
    name: str = "New Mix"

@app.post("/api/app-playlists/generate")
async def api_generate_app_playlist(request: GeneratePlaylistRequest):
    """Generate a new random playlist"""
    all_songs = await get_all_songs()
    if not all_songs:
        raise HTTPException(status_code=400, detail="No songs in library")
        
    import random
    count = min(15, len(all_songs))
    selected = random.sample(all_songs, count)
    
    # Try to make it somewhat thematic based on a random attribute
    # e.g. same artist, or just random
    
    song_ids = [s["id"] for s in selected]
    playlist_id = await create_app_playlist(
        name=request.name,
        song_ids=song_ids,
        description="Generated playlist"
    )
    
    return {"status": "created", "id": playlist_id, "count": len(song_ids)}


# ==================== YouTube Audio Download API ====================
from pydantic import BaseModel
from vidssave_downloader import (
    vidssave_downloader, get_vidssave_task, get_all_tasks as get_all_vidssave_tasks,
    VidsSaveDownloadStatus, VidsSaveDownloadTask, _vidssave_tasks
)
from database import (
    save_youtube_task, get_youtube_task, get_youtube_tasks,
    update_youtube_task, delete_youtube_task, clear_all_youtube_tasks
)


class YouTubeRequest(BaseModel):
    url: str
    quality: str = "320"


class YouTubePreviewRequest(BaseModel):
    url: str


async def sync_task_to_db(task_id: str):
    """Sync in-memory task state to MongoDB"""
    task = get_vidssave_task(task_id)
    if task:
        await save_youtube_task({
            "task_id": task.task_id,
            "url": task.url,
            "status": task.status.value,
            "progress": task.progress,
            "title": task.title,
            "artist": task.artist,
            "thumbnail": task.thumbnail,
            "duration": task.duration,
            "file_size": 0,
            "error": task.error or "",
            "quality": "320",  # VidsSave always uses 320kbps
            "song_id": None,
        })


async def process_youtube_download(task_id: str, url: str, quality: str):
    """
    Background task for downloading YouTube content using VidsSave API
    and uploading to Telegram.
    """
    print(f"[MAIN] Starting process_youtube_download for {task_id}")
    
    # Helper for progress callbacks
    async def on_progress(event_type: str, data: dict):
        try:
            await broadcast_task_update(task_id)
        except Exception as e:
            print(f"[MAIN] Progress broadcast error: {e}")
    
    try:
        # ============ STEP 1: DOWNLOAD AUDIO via VidsSave ============
        print(f"[MAIN] Step 1: Downloading AUDIO for {task_id}")
        audio_task = await vidssave_downloader.download_and_convert(
            url, 
            task_id=task_id, 
            broadcast_callback=on_progress
        )
        
        if audio_task.status == VidsSaveDownloadStatus.FAILED or audio_task.status == VidsSaveDownloadStatus.CANCELLED:
            print(f"[MAIN] Audio download failed: {audio_task.error}")
            await sync_task_to_db(task_id)
            return
        
        if not audio_task.file_path or not os.path.exists(audio_task.file_path):
            print(f"[MAIN] Audio file not found: {audio_task.file_path}")
            audio_task.status = VidsSaveDownloadStatus.FAILED
            audio_task.error = "Audio file not found after conversion"
            await sync_task_to_db(task_id)
            return
        
        # Create upload progress callback for audio (80-95%)
        import time
        last_broadcast = [time.time()]
        
        def audio_upload_progress(current, total, speed):
            now = time.time()
            if now - last_broadcast[0] >= 0.3 or current == total:
                # Update task with upload progress
                audio_task.phase = "uploading_audio"
                audio_task.downloaded_bytes = current
                audio_task.total_bytes = total
                
                if speed and speed > 0:
                    if speed > 1024 * 1024:
                        audio_task.speed = f"{speed / (1024 * 1024):.1f} MB/s"
                    elif speed > 1024:
                        audio_task.speed = f"{speed / 1024:.1f} KB/s"
                    else:
                        audio_task.speed = f"{speed:.0f} B/s"
                    
                    if total > 0:
                        remaining = total - current
                        eta_seconds = remaining / speed
                        m, s = divmod(int(eta_seconds), 60)
                        h, m = divmod(m, 60)
                        audio_task.eta = f"{h:02d}:{m:02d}:{s:02d}" if h > 0 else f"{m:02d}:{s:02d}"
                
                # Progress: 80-95% for audio upload
                if total > 0:
                    audio_task.progress = 80 + int((current / total) * 15)
                
                last_broadcast[0] = now
                
                # Broadcast update
                import asyncio
                try:
                    loop = asyncio.get_event_loop()
                    loop.create_task(broadcast_task_update(task_id))
                except:
                    pass
        
        # Upload audio to Telegram
        print(f"[MAIN] Uploading audio to Telegram: {audio_task.file_path}")
        audio_msg = await tg_client.upload_file(
            audio_task.file_path,
            progress_callback=audio_upload_progress,
            title=audio_task.title,
            artist=audio_task.artist,
            duration=audio_task.duration,
            thumbnail=audio_task.thumbnail
        )
        
        if not audio_msg:
            audio_task.status = VidsSaveDownloadStatus.FAILED
            audio_task.error = "Failed to upload audio to Telegram"
            await sync_task_to_db(task_id)
            return
        
        audio_telegram_id = str(audio_msg.id)
        print(f"[MAIN] Audio uploaded! Telegram ID: {audio_telegram_id}")
        
        # Get audio file info
        audio_file_size = os.path.getsize(audio_task.file_path) if os.path.exists(audio_task.file_path) else 0
        audio_file_name = os.path.basename(audio_task.file_path) if audio_task.file_path else f"{audio_task.title}.mp3"
        
        # Save audio to database
        song_id = await add_song(
            telegram_file_id=audio_telegram_id,
            audio_telegram_id=audio_telegram_id,
            title=audio_task.title,
            artist=audio_task.artist,
            album="YouTube",
            duration=audio_task.duration,
            cover_art=audio_task.thumbnail,
            file_name=audio_file_name,
            file_size=audio_file_size,
            thumbnail=audio_task.thumbnail,
            has_video=False
        )
        
        # Mark audio upload complete
        audio_task.progress = 95
        audio_task.phase = "complete"
        audio_task.speed = "Done"
        audio_task.eta = "--:--"
        await sync_task_to_db(task_id)
        await notify_update("library_updated")
        
        # ============ STEP 2: UPLOAD VIDEO (if available) ============
        # VidsSave downloads video first then converts to audio
        # The video file might still exist
        if audio_task.video_path and os.path.exists(audio_task.video_path):
            print(f"[MAIN] Step 2: Uploading VIDEO to Telegram: {audio_task.video_path}")
            
            # Video upload progress callback (95-100%)
            def video_upload_progress(current, total, speed):
                now = time.time()
                if now - last_broadcast[0] >= 0.3 or current == total:
                    audio_task.phase = "uploading_video"
                    audio_task.downloaded_bytes = current
                    audio_task.total_bytes = total
                    
                    if speed and speed > 0:
                        if speed > 1024 * 1024:
                            audio_task.speed = f"{speed / (1024 * 1024):.1f} MB/s"
                        elif speed > 1024:
                            audio_task.speed = f"{speed / 1024:.1f} KB/s"
                        else:
                            audio_task.speed = f"{speed:.0f} B/s"
                    
                    # Progress: 95-100% for video upload
                    if total > 0:
                        audio_task.progress = 95 + int((current / total) * 5)
                    
                    last_broadcast[0] = now
                    
                    try:
                        loop = asyncio.get_event_loop()
                        loop.create_task(broadcast_task_update(task_id))
                    except:
                        pass
            
            try:
                video_msg = await tg_client.upload_file(
                    audio_task.video_path,
                    progress_callback=video_upload_progress,
                    title=audio_task.title,
                    artist=audio_task.artist,
                    duration=audio_task.duration,
                    thumbnail=audio_task.thumbnail
                )
                
                if video_msg:
                    video_telegram_id = str(video_msg.id)
                    print(f"[MAIN] Video uploaded! Telegram ID: {video_telegram_id}")
                    
                    # Update song with video ID
                    await add_song(
                        title=audio_task.title,
                        artist=audio_task.artist,
                        video_telegram_id=video_telegram_id,
                        has_video=True
                    )
                    await notify_update("library_updated")
                else:
                    print(f"[MAIN] Video upload failed (non-critical)")
            except Exception as ve:
                print(f"[MAIN] Video upload error (non-critical): {ve}")
            finally:
                # Cleanup video file
                try:
                    os.remove(audio_task.video_path)
                except:
                    pass
        
        # Final status update - 100% complete
        audio_task.status = VidsSaveDownloadStatus.COMPLETE
        audio_task.progress = 100
        audio_task.phase = "complete"
        audio_task.speed = "Done"
        audio_task.eta = "--:--"
        await broadcast_task_update(task_id)
        await sync_task_to_db(task_id)
        
        # Cleanup audio temp file
        if audio_task.file_path and os.path.exists(audio_task.file_path):
            try:
                os.remove(audio_task.file_path)
            except:
                pass
                
        print(f"[MAIN] Download complete for {task_id}")
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        task = get_vidssave_task(task_id)
        if task:
            task.status = VidsSaveDownloadStatus.FAILED
            task.error = str(e)
        await sync_task_to_db(task_id)




@app.post("/api/youtube")
async def youtube_download(background_tasks: BackgroundTasks, request: YouTubeRequest):
    """
    Start a YouTube audio download task (Using VidsSave API).
    Returns task_id(s) for status polling.
    """
    if not vidssave_downloader.is_youtube_url(request.url):
        raise HTTPException(status_code=400, detail="Invalid YouTube URL")
    
    import uuid
    task_id = str(uuid.uuid4())
    
    # Pre-create task to ensure status existence
    _vidssave_tasks[task_id] = VidsSaveDownloadTask(
        task_id=task_id, 
        url=request.url,
        status=VidsSaveDownloadStatus.PENDING
    )
    await sync_task_to_db(task_id)
    
    # Start background process
    background_tasks.add_task(process_youtube_download, task_id, request.url, request.quality)
    
    return {"status": "started", "task_id": task_id}



@app.post("/api/youtube/formats")
async def get_youtube_formats_endpoint(request: YouTubePreviewRequest):
    """Get available audio formats for a YouTube video"""
    try:
        formats = await vidssave_downloader.get_formats(request.url)
        return {"status": "success", "formats": formats}
    except Exception as e:
        print(f"[YouTube] Format fetch error: {e}")
        return {"status": "success", "formats": []}


@app.post("/api/youtube/preview")
async def youtube_preview(request: YouTubePreviewRequest):
    """Get video preview info using VidsSave API"""
    try:
        info = await vidssave_downloader.get_video_info(request.url)
        return {
            "status": "success",
            "title": info["title"],
            "artist": info["artist"],
            "thumbnail": info["thumbnail"],
            "duration": info["duration"],
            "description": "",
            "channel": ""
        }
    except Exception as e:
        print(f"[YouTube] Preview error: {e}")
        raise HTTPException(status_code=400, detail=f"Metadata fetch failed: {str(e)}")





@app.get("/api/youtube/status/{task_id}")
async def youtube_status(task_id: str):
    """
    Get the status of a YouTube download task.
    Checks in-memory first, then falls back to MongoDB.
    """
    # Check in-memory tasks
    task = get_vidssave_task(task_id)
    if task:
        return {
            "task_id": task.task_id,
            "url": task.url,
            "status": task.status.value,
            "progress": task.progress,
            "title": task.title,
            "artist": task.artist,
            "thumbnail": task.thumbnail,
            "duration": task.duration,
            "error": task.error or ""
        }
    
    # Fall back to MongoDB (for persisted tasks)
    db_task = await get_youtube_task(task_id)
    if db_task:
        return db_task
    
    raise HTTPException(status_code=404, detail="Task not found")



@app.get("/api/youtube/tasks")
async def list_youtube_tasks(page: int = 1, limit: int = 10):
    """
    List all YouTube download tasks with pagination.
    Merges in-memory tasks with persisted DB tasks.
    """
    # 1. Get in-memory tasks (VidsSave)
    in_memory_tasks = []
    for task in _vidssave_tasks.values():
        in_memory_tasks.append({
            "task_id": task.task_id,
            "url": task.url,
            "status": task.status.value,
            "progress": task.progress,
            "title": task.title,
            "artist": task.artist,
            "thumbnail": task.thumbnail,
            "duration": task.duration,
            "error": task.error or "",
            "quality": "320",
            "media_type": "audio"
        })
    
    # 2. Get persisted tasks from DB
    db_result = await get_youtube_tasks(page=page, limit=limit)
    db_tasks = db_result.get("tasks", [])
    
    # 3. Merge: Active in-memory tasks override DB tasks with same ID
    # Normalize DB tasks to dicts if they aren't already
    merged_map = {}
    for t in db_tasks:
        t_dict = t if isinstance(t, dict) else t.dict()
        merged_map[t_dict["task_id"]] = t_dict
    
    # Add/Override with in-memory tasks
    for task in in_memory_tasks:
        merged_map[task["task_id"]] = task
        
    final_tasks = list(merged_map.values())
    
    # Sort: put active/pending tasks first, then by date?
    # For now, simplistic sort: In-memory/active ones usually have 'progress' < 100 or status not 'complete'
    # But for a stable list, maybe just reverse order (assuming newer tasks are at end or start of map)
    # The map insertion order is preserved in Python 3.7+
    
    # Pagination total might be slightly off if we merged new in-memory tasks not in DB
    # Recalculate basic total
    total_count = len(final_tasks) if len(final_tasks) > db_result.get("total", 0) else db_result.get("total", 0)

    return {
        "tasks": final_tasks,
        "page": page,
        "pages": db_result.get("pages", 1),
        "total": total_count
    }


@app.delete("/api/youtube/tasks")
async def clear_youtube_tasks():
    """
    Clear all YouTube download tasks from history.
    """
    deleted_count = await clear_all_youtube_tasks()
    return {
        "status": "success",
        "deleted_count": deleted_count,
        "message": f"Cleared {deleted_count} tasks"
    }


@app.delete("/api/youtube/tasks/{task_id}")
async def delete_single_task(task_id: str):
    """
    Delete a single YouTube task from history.
    """
    await delete_youtube_task(task_id)
    return {"status": "success", "message": "Task deleted"}


@app.post("/api/youtube/cancel/{task_id}")
async def youtube_cancel(task_id: str):
    """
    Cancel a running YouTube download.
    """
    task = get_vidssave_task(task_id)
    if not task:
        # Check if in DB
        db_task = await get_youtube_task(task_id)
        if not db_task:
            raise HTTPException(status_code=404, detail="Task not found")
        return {"status": "already_finished", "message": "Task already finished"}
    
    if task.status in [VidsSaveDownloadStatus.COMPLETE, VidsSaveDownloadStatus.FAILED, VidsSaveDownloadStatus.CANCELLED]:
        return {"status": "already_finished", "message": "Task already finished"}
    
    vidssave_downloader.cancel_task(task_id)
    return {
        "status": "cancelled",
        "message": "Cancellation requested"
    }


# ==================== Songs Management ====================

@app.get("/api/songs/paginated")
async def get_songs_page(page: int = 1, limit: int = 20):
    """Get paginated songs list"""
    return await get_songs_paginated(page=page, limit=limit)


@app.delete("/api/songs/{song_id}")
async def remove_song(song_id: str):
    """Delete a song from library"""
    success = await delete_song(song_id)
    if not success:
        raise HTTPException(status_code=404, detail="Song not found")
    return {"status": "success", "message": "Song deleted"}


@app.post("/api/songs/{song_id}/play")
async def mark_song_played(song_id: str):
    """Record that a song was played (for history)"""
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    await record_play(song_id)
    return {"status": "success"}


# ==================== Playlists ====================

class CreatePlaylistRequest(BaseModel):
    name: str
    songs: list = []


@app.get("/api/playlists")
async def list_playlists(page: int = 1, limit: int = 10):
    """Get paginated playlists"""
    return await get_playlists(page=page, limit=limit)


@app.post("/api/playlists/import-app-playlist/{playlist_id}")
async def import_app_playlist(playlist_id: str):
    """Import an App Playlist to User Library"""
    # Get App Playlist
    app_pl = await get_playlist_with_songs(playlist_id)
    if not app_pl:
        raise HTTPException(status_code=404, detail="App Playlist not found")
    
    # Create User Playlist
    name = app_pl.get("name", "Imported Playlist")
    song_ids = [s["id"] for s in app_pl.get("songs", [])]
    
    new_id = await create_playlist(name=name, songs=song_ids)
    
    # Notify clients
    await notify_update("library_updated")
    
    return {"status": "success", "id": new_id, "name": name}





@app.post("/api/playlists")
async def new_playlist(request: CreatePlaylistRequest):
    """Create a new playlist"""
    playlist_id = await create_playlist(name=request.name, songs=request.songs)
    return {"status": "success", "id": playlist_id}


@app.get("/api/playlists/{playlist_id}")
async def get_playlist(playlist_id: str):
    """Get a playlist with song details"""
    pl = await get_playlist_by_id(playlist_id)
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    # Fetch song details
    songs = []
    for sid in pl.get("songs", []):
        song = await get_song_by_id(sid)
        if song:
            songs.append(song)
    
    pl["song_details"] = songs
    return pl


@app.post("/api/playlists/{playlist_id}/songs")
async def add_to_playlist(playlist_id: str, song_id: str):
    """Add a song to a playlist"""
    success = await add_song_to_playlist(playlist_id, song_id)
    return {"status": "success" if success else "failed"}


@app.delete("/api/playlists/{playlist_id}/songs/{song_id}")
async def remove_from_playlist(playlist_id: str, song_id: str):
    """Remove a song from a playlist"""
    success = await remove_song_from_playlist(playlist_id, song_id)
    return {"status": "success" if success else "failed"}


@app.delete("/api/playlists/{playlist_id}")
async def remove_playlist(playlist_id: str):
    """Delete a playlist"""
    success = await delete_playlist(playlist_id)
    if not success:
        raise HTTPException(status_code=404, detail="Playlist not found")
    return {"status": "success"}


# ==================== Homepage ====================

@app.get("/api/home")
async def get_homepage():
    """Get homepage data with recently played and AI recommendations"""
    recently_played = await get_recently_played(limit=10)
    ai_cache = await get_ai_cache()
    
    # Get AI playlist song details
    ai_playlist_songs = []
    if ai_cache and ai_cache.get("ai_playlist_songs"):
        for sid in ai_cache["ai_playlist_songs"]:
            song = await get_song_by_id(sid)
            if song:
                ai_playlist_songs.append(song)
    
    return {
        "recently_played": recently_played,
        "recommendations": ai_cache.get("recommendations", []) if ai_cache else [],
        "ai_playlist": {
            "name": ai_cache.get("ai_playlist_name", "AI Mix") if ai_cache else "AI Mix",
            "songs": ai_playlist_songs
        },
        "last_updated": ai_cache.get("updated_at") if ai_cache else None
    }


@app.post("/api/home/refresh")
async def refresh_homepage(background_tasks: BackgroundTasks):
    """Manually trigger AI recommendations refresh"""
    async def do_refresh():
        all_songs = await get_all_songs()
        if all_songs:
            result = await get_homepage_recommendations(all_songs)
            await update_ai_cache(
                recommendations=result["recommendations"],
                ai_playlist_name=result["ai_playlist"]["name"],
                ai_playlist_songs=result["ai_playlist"]["song_ids"]
            )
    
    background_tasks.add_task(do_refresh)
    return {"status": "started", "message": "Refresh started in background"}


if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.environ.get("PORT", 8000))
    # Enable reload to pick up code changes AND config.env changes
    uvicorn.run(
        "main:app", 
        host="0.0.0.0", 
        port=port, 
        reload=True,
        reload_includes=["config.env", "*.env", "restart_required.flag"],
        reload_excludes=["temp_uploads", "__pycache__", "venv", ".git", "node_modules", ".pytest_cache", "FrontEnd"],
        timeout_graceful_shutdown=1
    )



