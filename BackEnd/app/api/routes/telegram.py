from fastapi import APIRouter, HTTPException

from app.db.connection import telegram_state_collection
from app.services.telegram import telegram_client, TelegramNotConfigured
from app.services.channel_indexer import scan_source_channel

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
