import os
from fastapi import APIRouter, UploadFile, File, HTTPException, Form
from typing import List

from app.api.routes.websocket import notify_update
from app.services.metadata import extract_metadata
from app.services.s3 import upload_file as s3_upload_file
from app.services.audio_extractor import (
    extract_audio_from_video,
    cleanup_extracted_file,
)
from app.db.crud.songs import add_song

router = APIRouter(prefix="/api/upload", tags=["upload"])

TEMP_UPLOAD_DIR = "temp_uploads"


@router.post("")
async def upload_files(files: List[UploadFile] = File(...)):
    """Upload audio or video files"""
    if not os.path.exists(TEMP_UPLOAD_DIR):
        os.makedirs(TEMP_UPLOAD_DIR)

    uploaded_songs = []
    total_files = len(files)

    for i, file in enumerate(files):
        file_name = file.filename
        file_index = i + 1

        # Broadcast: Processing started
        await notify_update(
            "upload_progress",
            {
                "file_name": file_name,
                "file_index": file_index,
                "total_files": total_files,
                "stage": "processing",
                "message": f"Processing {file_name}...",
            },
        )

        try:
            # Save locally first
            file_path = os.path.join(TEMP_UPLOAD_DIR, file_name)
            with open(file_path, "wb") as buffer:
                content = await file.read()
                buffer.write(content)

            is_video = False
            video_exts = [".mp4", ".mkv", ".webm", ".avi", ".mov"]
            if any(file_name.lower().endswith(ext) for ext in video_exts):
                is_video = True

            # Extract Metadata
            meta = await extract_metadata(file_path)

            # Broadcast: Uploading to S3
            await notify_update(
                "upload_progress",
                {
                    "file_name": file_name,
                    "file_index": file_index,
                    "total_files": total_files,
                    "stage": "s3_upload",
                    "message": f"Uploading {file_name} to S3...",
                },
            )

            # Upload main file to S3
            s3_key = await s3_upload_file(file_path)
            if not s3_key:
                await notify_update(
                    "upload_progress",
                    {
                        "file_name": file_name,
                        "file_index": file_index,
                        "total_files": total_files,
                        "stage": "error",
                        "message": f"Failed to upload {file_name} to S3",
                    },
                )
                if os.path.exists(file_path):
                    os.remove(file_path)
                continue

            audio_s3_key = None
            video_s3_key = None

            if is_video:
                video_s3_key = s3_key

                # Broadcast: Extracting audio
                await notify_update(
                    "upload_progress",
                    {
                        "file_name": file_name,
                        "file_index": file_index,
                        "total_files": total_files,
                        "stage": "extracting_audio",
                        "message": f"Extracting audio from {file_name}...",
                    },
                )

                # Extract audio
                audio_path = await extract_audio_from_video(file_path)
                if audio_path:
                    audio_key_res = await s3_upload_file(audio_path)
                    if audio_key_res:
                        audio_s3_key = audio_key_res
                    cleanup_extracted_file(audio_path)
            else:
                audio_s3_key = s3_key

            # Broadcast: Saving to database
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

            # Save to DB
            song_id = await add_song(
                s3_audio_key=audio_s3_key,
                s3_video_key=video_s3_key,
                has_video=is_video,
                title=meta.get("title"),
                artist=meta.get("artist"),
                album=meta.get("album"),
                duration=meta.get("duration"),
                cover_art=meta.get("cover_art"),
                file_name=file_name,
                file_size=os.path.getsize(file_path),
            )

            uploaded_songs.append({"id": song_id, "file_name": file_name})

            # Cleanup temp file
            if os.path.exists(file_path):
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
                os.remove(file_path)

    # Broadcast: Complete
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
