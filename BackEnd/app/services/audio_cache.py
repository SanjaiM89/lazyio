"""Disk cache for Telegram audio.

Problem it solves: browsers open MANY range requests per song (seeking,
buffering, re-requests after stalls). Without a cache, every request
re-downloads megabytes from Telegram's CDN, so big files can never be
served fast enough and the browser aborts/retries forever.

Design:
- First play streams THROUGH from Telegram while appending to `<id>.part`.
- When the part reaches the full file size it is renamed to `<id>.bin`.
- Complete files are served straight from disk (seeks are instant).
- A cached prefix of a `.part` file is served from disk, the rest is
  fetched from Telegram; only contiguous appends write to disk.
- LRU eviction keeps total cache under AUDIO_CACHE_MAX_MB (default 5GB).
"""

import asyncio
import os
import time
from pathlib import Path

CACHE_DIR = Path(os.getenv("AUDIO_CACHE_DIR", "cache/audio"))
MAX_CACHE_BYTES = int(os.getenv("AUDIO_CACHE_MAX_MB", "5120")) * 1024 * 1024
MAX_CACHED_FILE_BYTES = int(os.getenv("AUDIO_CACHE_MAX_FILE_MB", "300")) * 1024 * 1024
READ_CHUNK = 256 * 1024

_locks: dict[int, asyncio.Lock] = {}
_locks_guard = asyncio.Lock()
_appending: set[int] = set()


async def _lock_for(message_id: int) -> asyncio.Lock:
    async with _locks_guard:
        return _locks.setdefault(message_id, asyncio.Lock())


def _final(message_id: int) -> Path:
    return CACHE_DIR / f"{message_id}.bin"


def _part(message_id: int) -> Path:
    return CACHE_DIR / f"{message_id}.bin.part"


def _is_complete(message_id: int, file_size: int) -> bool:
    try:
        return _final(message_id).stat().st_size >= file_size
    except OSError:
        return False


def _touch(path: Path):
    try:
        os.utime(path, None)
    except OSError:
        pass


def _evict_if_needed():
    try:
        files = []
        total = 0
        for p in CACHE_DIR.glob("*.bin"):
            try:
                st = p.stat()
                files.append((st.st_mtime, st.st_size, p))
                total += st.st_size
            except OSError:
                continue
        if total <= MAX_CACHE_BYTES:
            return
        files.sort()
        for _, size, p in files:
            try:
                p.unlink()
                total -= size
                print(f"[CACHE] evicted {p.name} ({size // 1024 // 1024}MB)")
            except OSError:
                pass
            if total <= MAX_CACHE_BYTES:
                break
    except Exception as e:
        print(f"[CACHE] eviction warning: {e}")


async def _serve_range(path: Path, offset: int, length: int):
    """Yield [offset, offset+length) from a file on disk."""
    remaining = length
    with open(path, "rb") as f:
        f.seek(offset)
        while remaining > 0:
            data = f.read(min(READ_CHUNK, remaining))
            if not data:
                break
            yield data
            remaining -= len(data)


async def stream_with_cache(message_id: int, offset: int, length: int,
                            file_size: int, fetch):
    """Yield `length` bytes from `offset`, using disk cache when possible.

    `fetch(fetch_offset, fetch_length)` is an async generator pulling bytes
    from Telegram. Only one concurrent writer per message id; everyone else
    reads cache and passes the rest through.
    """
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cacheable = file_size <= MAX_CACHED_FILE_BYTES

    if cacheable and _is_complete(message_id, file_size):
        _touch(_final(message_id))
        async for chunk in _serve_range(_final(message_id), offset, length):
            yield chunk
        return

    we_write = False
    if cacheable:
        lock = await _lock_for(message_id)
        async with lock:
            if _is_complete(message_id, file_size):
                _touch(_final(message_id))
                async for chunk in _serve_range(_final(message_id), offset, length):
                    yield chunk
                return
            part = _part(message_id)
            try:
                part_size = part.stat().st_size
            except OSError:
                part_size = 0
            # Serve whatever prefix is already on disk.
            if offset < part_size:
                serve_until = min(offset + length, part_size)
                async for chunk in _serve_range(part, offset, serve_until - offset):
                    yield chunk
                served = serve_until - offset
                offset += served
                length -= served
                if length <= 0:
                    return
            # Claim the writer slot only for contiguous appends.
            try:
                cur_size = part.stat().st_size
            except OSError:
                cur_size = 0
            if message_id not in _appending and offset == cur_size:
                _appending.add(message_id)
                we_write = True

    if not we_write:
        # Pure passthrough: slow path, but never blocks on the writer.
        async for chunk in fetch(offset, length):
            yield chunk
        return

    # Stream-through: forward to client while appending to the part file.
    part = _part(message_id)
    try:
        with open(part, "ab") as f:
            async for chunk in fetch(offset, length):
                yield chunk
                try:
                    f.write(chunk)
                except OSError as e:
                    print(f"[CACHE] write failed for msg {message_id}: {e}")
                    break
        try:
            if part.stat().st_size >= file_size:
                part.rename(_final(message_id))
                print(f"[CACHE] completed msg {message_id} ({file_size // 1024 // 1024}MB)")
                _evict_if_needed()
        except OSError as e:
            print(f"[CACHE] finalize failed for msg {message_id}: {e}")
    finally:
        _appending.discard(message_id)
