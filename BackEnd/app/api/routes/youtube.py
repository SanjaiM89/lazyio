from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel

from app.db.crud.songs import add_song
from app.db.crud.tasks import (
    save_youtube_task,
    get_youtube_task,
    get_youtube_tasks,
    update_youtube_task,
    delete_youtube_task,
    clear_all_youtube_tasks,
)
from app.services.s3 import upload_file as s3_upload_file
from app.services.metadata import extract_metadata
from app.services.audio_extractor import (
    extract_audio_from_video,
    cleanup_extracted_file,
)
from app.services.youtube import youtube_downloader, get_task, DownloadStatus
from app.services.vidssave import vidssave_downloader
from app.api.routes.websocket import notify_update

import os
import asyncio

router = APIRouter(tags=["youtube"])


class YouTubeRequest(BaseModel):
    url: str
    quality: str = "320"


class YouTubePreviewRequest(BaseModel):
    url: str


async def broadcast_task_update(task_id: str):
    task = get_task(task_id)
    if task:
        await notify_update(
            "youtube_task_update",
            {
                "task_id": task.task_id,
                "status": task.status.value,
                "progress": task.progress,
                "speed": task.speed,
                "eta": task.eta,
                "title": task.title,
                "artist": task.artist,
                "error": task.error,
            },
        )


async def sync_task_to_db(task_id: str):
    task = get_task(task_id)
    if task:
        await save_youtube_task(
            {
                "task_id": task.task_id,
                "url": task.url,
                "status": task.status.value,
                "progress": task.progress,
                "title": task.title,
                "artist": task.artist,
                "thumbnail": task.thumbnail,
                "duration": task.duration,
                "file_size": task.file_size,
                "error": task.error,
                "quality": task.quality,
                "song_id": task.song_id,
            }
        )


async def process_youtube_download(task_id: str, url: str, quality: str):
    user_wants_video = quality == "best" or quality.endswith("p")

    def on_progress(task):
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(broadcast_task_update(task.task_id))
        except RuntimeError:
            pass

    def create_upload_callback(task, base_progress, progress_range):
        import time

        state = {"last_time": time.time(), "last_current": 0}

        def on_upload_progress(current, total, speed):
            now = time.time()
            dt = now - state["last_time"]

            if dt > 0.5 or current == total:
                if speed and speed > 0:
                    if speed > 1024 * 1024:
                        task.speed = f"{speed / (1024 * 1024):.2f} MiB/s"
                    else:
                        task.speed = f"{speed / 1024:.2f} KiB/s"
                    remaining = total - current
                    eta_seconds = remaining / speed
                    m, s = divmod(int(eta_seconds), 60)
                    h, m = divmod(m, 60)
                    task.eta = (
                        f"{h:02d}:{m:02d}:{s:02d}" if h > 0 else f"{m:02d}:{s:02d}"
                    )
                else:
                    task.speed = "0 B/s"
                    task.eta = "--:--"

                task.downloaded_bytes = current
                task.total_bytes = total

                percent = current / total * 100 if total else 0
                task.progress = base_progress + (percent * progress_range / 100)

                state["last_time"] = now
                state["last_current"] = current
                on_progress(task)

        return on_upload_progress

    task = await youtube_downloader.download_audio(url, quality, on_progress)
    await sync_task_to_db(task_id)

    if task.status == DownloadStatus.ERROR:
        await sync_task_to_db(task_id)
        return

    audio_file_path = task.file_path

    task.status = DownloadStatus.PROCESSING
    task.progress = 50.0
    task.speed = ""
    task.eta = ""
    on_progress(task)
    await sync_task_to_db(task_id)

    try:
        meta = await extract_metadata(audio_file_path)
    except Exception as e:
        print(f"[YOUTUBE] Metadata error: {e}")
        meta = {"title": task.title, "artist": task.artist, "duration": task.duration}

    task.status = DownloadStatus.UPLOADING
    task.progress = 60.0
    on_progress(task)
    await sync_task_to_db(task_id)

    upload_cb = create_upload_callback(task, 60.0, 30.0)
    audio_s3_key = await s3_upload_file(audio_file_path)

    if not audio_s3_key:
        task.status = DownloadStatus.ERROR
        task.error = "Failed to upload audio to S3"
        on_progress(task)
        await sync_task_to_db(task_id)
        return

    song_id = await add_song(
        s3_audio_key=audio_s3_key,
        s3_video_key=None,
        has_video=False,
        title=meta.get("title") or task.title,
        artist=meta.get("artist") or task.artist,
        duration=task.duration,
        cover_art=task.thumbnail,
        file_name=os.path.basename(audio_file_path),
        file_size=os.path.getsize(audio_file_path),
    )

    task.song_id = song_id
    task.status = DownloadStatus.COMPLETED
    task.progress = 100.0
    on_progress(task)
    await sync_task_to_db(task_id)
    await notify_update("library_updated")

    if os.path.exists(audio_file_path):
        os.remove(audio_file_path)

    if user_wants_video:
        print(f"[YOUTUBE] Starting background video download for {song_id}")
        task.status = DownloadStatus.DOWNLOADING
        task.progress = 0.0
        task.eta = "Downloading Video"
        on_progress(task)
        await sync_task_to_db(task_id)

        video_task = await youtube_downloader.download_video(url, quality, on_progress)
        if video_task.status == DownloadStatus.ERROR:
            task.error = f"Video failed: {video_task.error}"
            task.status = DownloadStatus.ERROR
            on_progress(task)
            await sync_task_to_db(task_id)
            return

        video_file_path = video_task.file_path

        task.status = DownloadStatus.UPLOADING
        task.progress = 50.0
        task.eta = "Uploading Video to S3"
        on_progress(task)
        await sync_task_to_db(task_id)

        video_s3_key = await s3_upload_file(video_file_path)

        if video_s3_key:
            from app.db.crud.songs import update_song_video

            await update_song_video(song_id, video_s3_key)
            task.status = DownloadStatus.COMPLETED
            task.progress = 100.0
            task.eta = "Video Processed"
            on_progress(task)
            await sync_task_to_db(task_id)
            await notify_update("library_updated")
        else:
            task.status = DownloadStatus.ERROR
            task.error = "Video upload to S3 failed"
            on_progress(task)
            await sync_task_to_db(task_id)

        if os.path.exists(video_file_path):
            os.remove(video_file_path)


@router.post("/api/youtube/download")
async def api_youtube_download(
    request: YouTubeRequest, background_tasks: BackgroundTasks
):
    info = await youtube_downloader.get_info(request.url)
    if not info:
        raise HTTPException(status_code=400, detail="Could not fetch video info")

    task_id = youtube_downloader.create_task(request.url, info, request.quality)
    await sync_task_to_db(task_id)
    background_tasks.add_task(
        process_youtube_download, task_id, request.url, request.quality
    )
    return {"status": "started", "task_id": task_id}


@router.post("/api/vidssave/download")
async def api_vidssave_download(
    request: YouTubeRequest, background_tasks: BackgroundTasks
):
    info = await vidssave_downloader.get_info(request.url)
    if not info:
        raise HTTPException(status_code=400, detail="Could not fetch info via VidsSave")

    task_id = vidssave_downloader.create_task(request.url, info, request.quality)
    await sync_task_to_db(task_id)
    background_tasks.add_task(
        process_youtube_download, task_id, request.url, request.quality
    )
    return {"status": "started", "task_id": task_id, "provider": "vidssave"}


@router.get("/api/youtube/tasks")
async def api_youtube_tasks(page: int = 1, limit: int = 10):
    return await get_youtube_tasks(page, limit)


@router.delete("/api/youtube/tasks/{task_id}")
async def api_delete_youtube_task(task_id: str):
    await delete_youtube_task(task_id)
    return {"status": "success"}


@router.delete("/api/youtube/tasks")
async def api_clear_youtube_tasks():
    deleted = await clear_all_youtube_tasks()
    return {"status": "success", "deleted": deleted}
