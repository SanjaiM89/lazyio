from fastapi import APIRouter, HTTPException

from app.db.connection import telegram_state_collection
from app.services.telegram import telegram_client, TelegramNotConfigured
from app.services.channel_indexer import scan_source_channel
from app.services.artwork import debug_match, TransientStoreError

router = APIRouter(prefix="/api/telegram", tags=["telegram"])


@router.get("/status")
async def telegram_status():
    state = await telegram_state_collection.find_one({"_id": "source_channel"})
    if state:
        state.pop("_id", None)
    return {
        "configured": telegram_client.configured,
        "channel": str(telegram_client.source_channel or ""),
        "state": state or {},
    }


@router.post("/scan")
async def telegram_scan(limit: int = 0, force: bool = False):
    try:
        result = await scan_source_channel(limit=limit, force=force)
    except TelegramNotConfigured as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Scan failed: {e}")
    try:
        from app.api.routes.websocket import notify_update

        await notify_update("library_updated")
    except Exception:
        pass
    return {"status": "success", **result}


@router.get("/test-match")
async def telegram_test_match(title: str, artist: str = ""):
    """Diagnostics: why does (or doesn't) a song get store metadata?

    Shows every query tried plus each raw iTunes candidate with its
    accept/reject reason. Nothing is cached or written.
    """
    try:
        return await debug_match(title, artist)
    except TransientStoreError as e:
        raise HTTPException(status_code=502, detail=f"Store unreachable: {e}")


@router.post("/backfill-artwork")
async def backfill_artwork(limit: int = 100):
    """Fetch cover art for songs missing artwork via iTunes."""
    from app.services.channel_indexer import backfill_missing_artwork

    result = await backfill_missing_artwork(limit=limit)
    try:
        from app.api.routes.websocket import notify_update
        await notify_update("library_updated")
    except Exception:
        pass
    return {"status": "success", **result}


@router.get("/audit")
async def audit_coverage(limit: int = 200, repair: bool = False):
    """Show which channel files are indexed, missing, or unsupported.

    repair=true indexes the missing ones on the spot.
    """
    from app.services.channel_indexer import audit_channel

    limit = max(1, min(limit, 500))
    return await audit_channel(limit=limit, repair=repair)
