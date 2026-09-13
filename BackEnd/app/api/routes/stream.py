import asyncio
import re
import time
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse

from app.db.crud.songs import get_song_raw_by_id
from app.services.telegram import telegram_client

router = APIRouter(prefix="/api/stream", tags=["stream"])

CHUNK_SIZE = 256 * 1024
STREAM_TIMEOUT = 30
INACTIVITY_TIMEOUT = 10


@router.get("/{song_id}")
async def stream_song(song_id: str, request: Request, type: str = "audio"):
    song = await get_song_raw_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    message_id = song.get("telegram_message_id")
    if not message_id:
        s3_key = song.get("s3_audio_key") or song.get("s3_video_key")
        if s3_key:
            try:
                from app.services.s3 import get_presigned_url
                from fastapi.responses import RedirectResponse

                url = await get_presigned_url(s3_key)
                if url:
                    return RedirectResponse(url=url, status_code=302)
            except Exception as e:
                print(f"[STREAM] S3 fallback failed: {e}")
        raise HTTPException(status_code=404, detail="Song has no Telegram media")

    try:
        info = await telegram_client.file_info(message_id)
    except Exception as e:
        from app.services.telegram import TelegramBotLimitedError

        if isinstance(e, TelegramBotLimitedError):
            raise HTTPException(status_code=503, detail=str(e))
        raise
    if not info:
        raise HTTPException(status_code=404, detail="Telegram media not found")
    file_size = info["file_size"]
    mime_type = info.get("mime_type") or "audio/mpeg"

    range_header = request.headers.get("range")
    start = 0
    end = file_size - 1
    status_code = 200
    if range_header:
        m = re.match(r"bytes=(\d*)-(\d*)", range_header.strip())
        if m:
            s, e = m.groups()
            if s:
                start = int(s)
            if e:
                end = int(e)
            end = min(end, file_size - 1)
            if start > end:
                raise HTTPException(status_code=416, detail="Invalid range")
            status_code = 206

    length = end - start + 1

    async def gen():
        last_chunk_time = time.monotonic()
        try:
            async for chunk in telegram_client.stream_file(
                message_id, offset=start, limit=length
            ):
                if await request.is_disconnected():
                    print(f"[STREAM] Client disconnected for song {song_id}")
                    return
                last_chunk_time = time.monotonic()
                yield chunk
        except Exception as e:
            elapsed = time.monotonic() - last_chunk_time
            print(f"[STREAM] Error streaming {song_id} after {elapsed:.1f}s: {e}")
            return

    headers = {
        "Accept-Ranges": "bytes",
        "Content-Length": str(length),
        "Content-Type": mime_type,
    }
    if status_code == 206:
        headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"

    return StreamingResponse(gen(), status_code=status_code, headers=headers, media_type=mime_type)
