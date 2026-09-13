import re
import time
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse, Response

from app.db.crud.songs import get_song_raw_by_id
from app.services.telegram import telegram_client

router = APIRouter(prefix="/api/stream", tags=["stream"])

CHUNK_SIZE = 256 * 1024


@router.get("/diagnose/{song_id}")
async def diagnose_song(song_id: str):
    """Check if a song's Telegram media is accessible."""
    song = await get_song_raw_by_id(song_id)
    if not song:
        return {"status": "error", "detail": "Song not in DB"}

    message_id = song.get("telegram_message_id")
    if not message_id:
        return {"status": "error", "detail": "No telegram_message_id"}

    try:
        info = await telegram_client.file_info(message_id)
    except Exception as e:
        return {"status": "error", "detail": f"file_info failed: {e}", "message_id": message_id}

    if not info:
        return {"status": "error", "detail": "file_info returned None", "message_id": message_id}

    media = info.get("media")
    file_size = info.get("file_size", 0)

    ok = False
    err = None
    if media:
        try:
            client = await telegram_client._ensure()
            count = 0
            async for chunk in client.iter_download(media, limit=1024):
                count += len(chunk)
                if count >= 1024:
                    break
            ok = count > 0
        except Exception as e:
            err = str(e)

    return {
        "status": "ok" if ok else "error",
        "message_id": message_id,
        "file_name": info.get("file_name"),
        "file_size": file_size,
        "mime_type": info.get("mime_type"),
        "error": err,
        "title": song.get("title"),
        "artist": song.get("artist"),
    }


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
        print(f"[STREAM] file_info error for {song_id} (msg={message_id}): {e}")
        raise HTTPException(status_code=502, detail=f"Telegram error: {e}")
    if not info:
        print(f"[STREAM] No media for {song_id} (msg={message_id})")
        raise HTTPException(status_code=404, detail="Telegram media not found")

    file_size = info["file_size"]
    mime_type = info.get("mime_type") or "audio/mpeg"
    media = info["media"]
    media_type = media.__class__.__name__ if media is not None else "None"
    range_header = request.headers.get("range")

    print(f"[STREAM] {song_id} msg={message_id} size={file_size} mime={mime_type} media={media_type} range={range_header!r}")

    if not media:
        print(f"[STREAM] Media object is None for {song_id} (msg={message_id})")
        raise HTTPException(status_code=404, detail="Telegram media object is None")

    if not file_size or file_size <= 0:
        print(f"[STREAM] Refusing to stream {song_id} (msg={message_id}): file_size={file_size}")
        raise HTTPException(status_code=404, detail=f"Telegram file has no size (size={file_size})")

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
        yielded = 0
        chunks = 0
        try:
            async def fetch(fetch_offset: int, fetch_length: int):
                async for chunk in telegram_client.stream_file(
                    message_id, offset=fetch_offset, limit=fetch_length,
                    media=media, file_size=file_size,
                ):
                    yield chunk

            from app.services.audio_cache import stream_with_cache
            async for chunk in stream_with_cache(
                message_id, start, length, file_size, fetch
            ):
                if await request.is_disconnected():
                    print(f"[STREAM] {song_id}: client disconnected after {yielded} bytes")
                    return
                yielded += len(chunk)
                chunks += 1
                yield chunk
        except Exception as e:
            print(f"[STREAM] {song_id} (msg={message_id}): EXCEPTION after {yielded} bytes in {chunks} chunks: {type(e).__name__}: {e}")
            return
        print(f"[STREAM] {song_id} (msg={message_id}): done, sent {yielded}/{length} bytes in {chunks} chunks")

    headers = {
        "Accept-Ranges": "bytes",
        "Content-Length": str(length),
        "Content-Type": mime_type,
    }
    if status_code == 206:
        headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"

    return StreamingResponse(gen(), status_code=status_code, headers=headers, media_type=mime_type)
