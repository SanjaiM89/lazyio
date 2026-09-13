import re
import asyncio
import struct
import time
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse, Response

from app.db.crud.songs import get_song_raw_by_id
from app.services.telegram import telegram_client

router = APIRouter(prefix="/api/stream", tags=["stream"])

CHUNK_SIZE = 256 * 1024

# Codecs that browsers (Chrome/Firefox) cannot play natively.
# These need real-time transcoding to AAC.
_UNSUPPORTED_CODECS = {b"alac", b"ALAC"}


_ALAC_CACHE: dict[str, bool] = {}


def _detect_alac(header: bytes) -> bool:
    """Check if an M4A header contains the ALAC codec.

    Parses the moov->trak->mdia->minf->stbl->stsd atom chain looking for
    the 'alac' codec tag. Only needs the first ~8KB of the file.
    """
    def _find_atom(data: bytes, name: bytes, offset: int = 0, end: int = 0) -> tuple:
        """Return (payload_offset, payload_end) for the first atom named `name`."""
        if end == 0:
            end = len(data)
        while offset < end - 8:
            size = struct.unpack(">I", data[offset:offset + 4])[0]
            atom_name = data[offset + 4:offset + 8]
            if size < 8:
                break
            atom_end = min(offset + size, end)
            if atom_name == name:
                return (offset + 8, atom_end)
            offset = atom_end
        return (0, 0)

    try:
        # Walk: moov -> trak -> mdia -> minf -> stbl -> stsd
        s, e = _find_atom(header, b"moov")
        if not s:
            return False
        s, e = _find_atom(header, b"trak", s, e)
        if not s:
            return False
        s, e = _find_atom(header, b"mdia", s, e)
        if not s:
            return False
        s, e = _find_atom(header, b"minf", s, e)
        if not s:
            return False
        s, e = _find_atom(header, b"stbl", s, e)
        if not s:
            return False
        s, e = _find_atom(header, b"stsd", s, e)
        if not s:
            return False
        # stsd has 8 bytes of version/flags + entry count before entries.
        # Each entry starts with size(4) + codec_tag(4).
        entry_off = s + 8  # skip version(4) + entry_count(4)
        if entry_off + 8 <= e:
            codec_tag = header[entry_off + 4:entry_off + 8]
            return codec_tag in _UNSUPPORTED_CODECS
    except Exception:
        pass
    return False


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


@router.api_route("/{song_id}", methods=["GET", "HEAD"])
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

    # Telegram often reports non-standard MIME types that browsers reject
    # (MEDIA_ERR_SRC_NOT_SUPPORTED).  Normalise to valid HTML5 audio types.
    _MIME_MAP = {
        "audio/m4a":   "audio/mp4",
        "audio/x-m4a": "audio/mp4",
        "audio/x-wav": "audio/wav",
        "audio/x-flac": "audio/flac",
        "audio/x-aac": "audio/aac",
        "audio/x-ogg": "audio/ogg",
    }
    mime_type = _MIME_MAP.get(mime_type, mime_type)
    media = info["media"]
    media_type = media.__class__.__name__ if media is not None else "None"
    range_header = request.headers.get("range")

    if not media:
        print(f"[STREAM] Media object is None for {song_id} (msg={message_id})")
        raise HTTPException(status_code=404, detail="Telegram media object is None")

    if not file_size or file_size <= 0:
        print(f"[STREAM] Refusing to stream {song_id} (msg={message_id}): file_size={file_size}")
        raise HTTPException(status_code=404, detail=f"Telegram file has no size (size={file_size})")

    # ── Detect ALAC and transcode if needed (cached) ─────────────────
    needs_transcode = _ALAC_CACHE.get(song_id)
    if needs_transcode is None:
        if mime_type == "audio/mp4":
            header_bytes = b""
            async for chunk in telegram_client.stream_file(
                message_id, offset=0, limit=8192,
                media=media, file_size=file_size,
            ):
                header_bytes += chunk
                if len(header_bytes) >= 8192:
                    break
            needs_transcode = _detect_alac(header_bytes)
        else:
            needs_transcode = False
        _ALAC_CACHE[song_id] = needs_transcode

    if needs_transcode:
        print(f"[STREAM] {song_id} msg={message_id} size={file_size} ALAC->AAC transcode method={request.method} range={range_header!r}")
        return await _stream_transcoded(song_id, message_id, media, file_size, request)

    # Handle HEAD request for normal files
    if request.method == "HEAD":
        headers = {
            "Accept-Ranges": "bytes",
            "Content-Length": str(file_size),
            "Content-Type": mime_type,
        }
        return Response(status_code=200, headers=headers, media_type=mime_type)

    # ── Normal (non-ALAC) streaming path ─────────────────────────────
    print(f"[STREAM] {song_id} msg={message_id} size={file_size} mime={mime_type} media={media_type} range={range_header!r}")

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
                # Safety cap: never exceed the declared Content-Length.
                remaining = length - yielded
                if len(chunk) > remaining:
                    chunk = chunk[:remaining]
                if not chunk:
                    break
                yielded += len(chunk)
                chunks += 1
                yield chunk
                if yielded >= length:
                    break
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


async def _stream_transcoded(song_id: str, message_id: int, media, file_size: int, request: Request):
    """Stream an ALAC song transcoded to AAC via ffmpeg.

    Because transcoding changes the file size, we cannot support Range
    requests -- the response is always a full 200 with chunked transfer
    encoding (no Content-Length) and Accept-Ranges: none.
    """
    headers = {
        "Content-Type": "audio/mp4",
        "Accept-Ranges": "none",
    }

    if request.method == "HEAD":
        return Response(status_code=200, headers=headers, media_type="audio/mp4")

    async def gen():
        proc = None
        try:
            # ffmpeg reads from stdin (pipe:0), transcodes ALAC->AAC,
            # outputs a fragmented MP4 to stdout (pipe:1).
            # -movflags +frag_keyframe+empty_moov+default_base_moof makes the MP4 streamable
            # without needing to seek back and rewrite the moov atom.
            # -frag_duration 200000 forces small 200ms fragments for sub-second TTFB.
            proc = await asyncio.subprocess.create_subprocess_exec(
                "ffmpeg",
                "-i", "pipe:0",             # read from stdin
                "-vn",                       # no video
                "-c:a", "aac",               # transcode to AAC
                "-b:a", "256k",              # high quality bitrate
                "-f", "mp4",                 # MP4 container
                "-movflags", "+frag_keyframe+empty_moov+default_base_moof",
                "-frag_duration", "200000",
                "pipe:1",                    # write to stdout
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            async def feed_stdin():
                """Download from Telegram and pipe into ffmpeg's stdin."""
                try:
                    async for chunk in telegram_client.stream_file(
                        message_id, offset=0, limit=file_size,
                        media=media, file_size=file_size,
                    ):
                        if proc.stdin.is_closing():
                            break
                        proc.stdin.write(chunk)
                        await proc.stdin.drain()
                except Exception as e:
                    print(f"[TRANSCODE] feed error for {song_id}: {e}")
                finally:
                    try:
                        proc.stdin.close()
                        await proc.stdin.wait_closed()
                    except Exception:
                        pass

            # Start feeding in the background
            feed_task = asyncio.create_task(feed_stdin())

            # Read transcoded output from ffmpeg's stdout
            yielded = 0
            while True:
                chunk = await proc.stdout.read(CHUNK_SIZE)
                if not chunk:
                    break
                if await request.is_disconnected():
                    print(f"[TRANSCODE] {song_id}: client disconnected after {yielded} bytes")
                    break
                yielded += len(chunk)
                yield chunk

            await feed_task
            print(f"[TRANSCODE] {song_id} (msg={message_id}): done, sent {yielded} bytes")

        except Exception as e:
            print(f"[TRANSCODE] {song_id} (msg={message_id}): EXCEPTION: {type(e).__name__}: {e}")
        finally:
            if proc and proc.returncode is None:
                try:
                    proc.kill()
                    await proc.wait()
                except Exception:
                    pass

    return StreamingResponse(gen(), status_code=200, headers=headers, media_type="audio/mp4")
