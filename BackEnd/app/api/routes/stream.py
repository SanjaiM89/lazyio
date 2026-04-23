from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import RedirectResponse

from app.db.crud.songs import get_song_by_id
from app.services.s3 import get_presigned_url

router = APIRouter(prefix="/api/stream", tags=["stream"])


@router.get("/{song_id}")
async def stream_song(song_id: str, request: Request, type: str = "audio"):
    """
    Get a presigned S3 URL and issue a 302 Redirect.
    type: "audio" or "video"
    """
    song = await get_song_by_id(song_id)
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    s3_key = None
    if type == "audio":
        s3_key = song.get("s3_audio_key")
    elif type == "video":
        s3_key = song.get("s3_video_key")
        if not s3_key:
            raise HTTPException(status_code=404, detail="Video stream not available")
    else:
        s3_key = song.get("s3_audio_key") or song.get("s3_video_key")

    if s3_key:
        print(f"[STREAM] Request for {song_id} -> S3 Key: {s3_key} (Type: {type})")
        presigned_url = await get_presigned_url(s3_key)
        if presigned_url:
            return RedirectResponse(url=presigned_url, status_code=302)
        else:
            raise HTTPException(
                status_code=500, detail="Failed to generate S3 stream URL"
            )

    raise HTTPException(status_code=404, detail="Song has no streamable file ID in S3")
