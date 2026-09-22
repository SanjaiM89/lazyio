import os
from fastapi import APIRouter, UploadFile, File, BackgroundTasks
from typing import List

from app.api.routes.websocket import notify_update
from app.services.metadata import extract_metadata
from app.services.telegram import telegram_client
from app.services.analysis_jobs import analyze_local_file
from app.db.crud.songs import add_song

router = APIRouter(prefix="/api/upload", tags=["upload"])

TEMP_UPLOAD_DIR = "temp_uploads"


@router.post("")
async def upload_files(
    files: List[UploadFile] = File(...), background_tasks: BackgroundTasks = None
):
    """Upload audio/video files straight to the Telegram source channel."""
    if not os.path.exists(TEMP_UPLOAD_DIR):
        os.makedirs(TEMP_UPLOAD_DIR)

    uploaded_songs = []
    total_files = len(files)

    for i, file in enumerate(files):
        file_name = file.filename or f"upload_{i}.mp3"
        file_index = i + 1

        await notify_update(
            "upload_progress",
            {
                "file_name": file_name,
                "file_index": file_index,
                "total_files": total_files,
                "stage": "saving",
                "message": f"Saving {file_name}...",
            },
        )

        file_path = os.path.join(TEMP_UPLOAD_DIR, file_name)
        try:
            with open(file_path, "wb") as buffer:
                content = await file.read()
                buffer.write(content)

            await notify_update(
                "upload_progress",
                {
                    "file_name": file_name,
                    "file_index": file_index,
                    "total_files": total_files,
                    "stage": "metadata",
                    "message": f"Reading metadata for {file_name}...",
                },
            )
            meta = await extract_metadata(file_path)

            await notify_update(
                "upload_progress",
                {
                    "file_name": file_name,
                    "file_index": file_index,
                    "total_files": total_files,
                    "stage": "telegram",
                    "message": f"Uploading {file_name} to Telegram...",
                },
            )
            msg = await telegram_client.upload_file(
                file_path,
                caption=f"{meta.get('artist', '')} - {meta.get('title', file_name)}".strip(" -"),
                title=meta.get("title"),
                artist=meta.get("artist"),
                duration=int(meta.get("duration") or 0),
            )

            await notify_update(
                "upload_progress",
                {
                    "file_name": file_name,
                    "file_index": file_index,
                    "total_files": total_files,
                    "stage": "database",
                    "message": f"Saving {file_name} to database...",
                },
            )
            lower = file_name.lower()
            is_video = any(lower.endswith(ext) for ext in [".mp4", ".mkv", ".webm", ".avi", ".mov"])
            song_id = await add_song(
                telegram_message_id=getattr(msg, "id", None),
                title=meta.get("title") or file_name,
                artist=meta.get("artist"),
                album=meta.get("album"),
                duration=meta.get("duration"),
                cover_art=meta.get("cover_art"),
                file_name=file_name,
                file_size=os.path.getsize(file_path) if os.path.exists(file_path) else 0,
                has_video=is_video,
                source_channel=str(telegram_client.source_channel),
            )
            uploaded_songs.append({"id": song_id, "file_name": file_name})

            # Analyze in the background (descriptors + similarity vector),
            # then delete the temp file. Falls back to immediate delete.
            if background_tasks is not None:
                background_tasks.add_task(
                    analyze_local_file, song_id, file_path, True
                )
            elif os.path.exists(file_path):
                os.remove(file_path)
        except Exception as e:
            print(f"[UPLOAD] Error processing {file_name}: {e}")
            await notify_update(
                "upload_progress",
                {
                    "file_name": file_name,
                    "file_index": file_index,
                    "total_files": total_files,
                    "stage": "error",
                    "message": f"Error: {str(e)}",
                },
            )
            if os.path.exists(file_path):
                try:
                    os.remove(file_path)
                except Exception:
                    pass

    await notify_update(
        "upload_progress",
        {
            "stage": "complete",
            "message": f"Successfully processed {len(uploaded_songs)} of {total_files} files.",
        },
    )
    await notify_update("library_updated")

    return {
        "status": "success",
        "uploaded": len(uploaded_songs),
        "songs": uploaded_songs,
    }
