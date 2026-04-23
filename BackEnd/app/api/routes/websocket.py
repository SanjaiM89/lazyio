from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import List

router = APIRouter()


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        # We need a copy of the list because connections might be removed during iteration
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except RuntimeError as e:
                if "websocket.close" in str(e):
                    self.disconnect(connection)
                else:
                    print(f"[WS] Broadcast error: {e}")
                    self.disconnect(connection)
            except Exception as e:
                print(f"[WS] Unexpected broadcast error: {e}")
                self.disconnect(connection)


manager = ConnectionManager()


async def notify_update(update_type: str, data: dict = None):
    """Utility to broadcast updates to all connected clients"""
    message = {"type": update_type}
    if data:
        message["data"] = data
    await manager.broadcast(message)


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
