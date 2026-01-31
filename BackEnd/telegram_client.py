import asyncio
import os
import time
import mimetypes
from typing import AsyncGenerator, Dict, Any, Optional

# 1. OPTIMIZATION: Install uvloop for faster async handling
try:
    import uvloop
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
except ImportError:
    pass

from telethon import TelegramClient, events, utils, errors
from telethon.tl.types import DocumentAttributeFilename, InputPeerChannel
from dotenv import load_dotenv

# Load env
load_dotenv("../config.env")
load_dotenv("config.env")

API_ID = os.getenv("API_ID")
API_HASH = os.getenv("API_HASH")
BOT_TOKEN = os.getenv("BOT_TOKEN")
BIN_CHANNEL = int(os.getenv("BIN_CHANNEL", "0"))

print(f"DEBUG: API_ID={API_ID} BIN_CHANNEL={BIN_CHANNEL}")

class FileNotFound(Exception):
    pass

class TelegramClientWrapper:
    def __init__(self):
        if not all([API_ID, API_HASH, BOT_TOKEN, BIN_CHANNEL]):
            raise ValueError("Missing Telegram Config")
        
        # 1. OPTIMIZATION: Multi-Client Pool (IDM Style)

        # We spawn multiple clients to open multiple TCP connections.
        # Configurable via env var, default 4 for best performance
        self.pool_size = int(os.getenv("TELEGRAM_POOL_SIZE", "4"))
        self.clients = []
        self.session_base = "TelethonBot"
        self.bin_channel = BIN_CHANNEL
        self._bin_entity = None
        
        # Initialize the pool
        for i in range(self.pool_size):
            session_name = f"{self.session_base}_worker_{i}"
            client = TelegramClient(
                session_name,
                int(API_ID),
                API_HASH,
                connection_retries=5,
                retry_delay=1,
                flood_sleep_threshold=60
            )
            self.clients.append(client)
            print(f"[INIT] Prepared worker {i}: {session_name}")

        # The primary client (worker 0) for general tasks
        self.client = self.clients[0]

    async def start(self):
        print(f"Starting {self.pool_size} Telegram Clients (Multi-Socket)...")
        
        # Start all clients in parallel, with FloodWait handling
        for i, client in enumerate(self.clients):
            max_retries = 3
            for attempt in range(max_retries):
                try:
                    await client.start(bot_token=BOT_TOKEN)
                    print(f"[TG] Worker {i} started successfully.")
                    break
                except errors.FloodWaitError as e:
                    wait_time = e.seconds
                    print(f"[TG] Worker {i} hit FloodWait: Waiting {wait_time} seconds...")
                    await asyncio.sleep(wait_time + 1) # Wait the required time + 1s buffer
                except Exception as e:
                    print(f"[TG] Worker {i} failed to start (attempt {attempt+1}): {e}")
                    if attempt == max_retries - 1:
                        print(f"[TG] CRITICAL: Worker {i} could not start after {max_retries} attempts.")
        
        # Check cryptg
        try:
            import cryptg
            print("🚀 Fast Crypto (cryptg) is detected and active.")
        except ImportError:
            print("⚠️ PERFORMANCE WARNING: 'cryptg' is not installed! Streaming will be slow.")
        
        me = await self.client.get_me()
        print(f"Bot info: {me.first_name} (@{me.username}) | Pool Size: {self.pool_size}")
        
        # Resolve entity using primary client
        await self._resolve_bin_channel()

    async def stop(self):
        print("Stopping Telegram Client Pool...")
        tasks = [client.disconnect() for client in self.clients]
        await asyncio.gather(*tasks)

    async def _resolve_bin_channel(self):
        """Resolves and caches the BIN_CHANNEL entity for ALL clients."""
        try:
            # Resolve on primary client first
            self._bin_entity = await self.client.get_input_entity(self.bin_channel)
            print(f"✅  Resolved BIN_CHANNEL (Worker 0): {self.bin_channel}")
            
            # Resolve on other workers to populate their cache
            # This ensures they can fetch messages during retries
            for i, worker in enumerate(self.clients[1:], 1):
                try:
                    await worker.get_input_entity(self.bin_channel)
                    print(f"✅  Resolved BIN_CHANNEL (Worker {i}): {self.bin_channel}")
                except Exception as e:
                    print(f"⚠️ Worker {i} failed to resolve channel: {e}")
                    
        except Exception as e:
            print(f"❌  Could not resolve BIN_CHANNEL: {e}")
            print("   Uploads might fail if the bot hasn't seen the channel yet.")

    async def download_media(self, message_id: int, file_path: str):
        """Download media to a local file path"""
        try:
             # Use worker 0 for simplicity or implement round robin if needed
             message = await self.client.get_messages(self.bin_channel, ids=message_id)
             if not message or not message.media:
                 raise FileNotFound(f"Message {message_id} not found")
                 
             await self.client.download_media(message, file_path)
             return file_path
        except Exception as e:
            print(f"[TG] Download failed: {e}")
            return None

    def _sanitize_filename(self, filename: str) -> str:
        import re
        filename = filename.replace('｜', '-').replace('|', '-')
        filename = re.sub(r'[<>:"/\\?*]', '', filename)
        if len(filename) > 200:
            name, ext = os.path.splitext(filename)
            filename = name[:195] + ext
        return filename

    async def upload_file(
        self, 
        file_path: str, 
        progress_callback=None,
        title: str = None,
        artist: str = None,
        duration: int = 0,
        thumbnail: str = None
    ) -> Optional[Any]:
        if not os.path.exists(file_path):
            return None

        clean_name = self._sanitize_filename(os.path.basename(file_path))
        start_time = time.time()
        
        async def _progress(current, total):
            if progress_callback:
                now = time.time()
                elapsed = now - start_time
                speed = current / elapsed if elapsed > 0 else 0
                progress_callback(current, total, speed)

        # Download thumbnail if URL provided
        thumb_path = None
        if thumbnail and (thumbnail.startswith("http://") or thumbnail.startswith("https://")):
            try:
                import urllib.request
                import uuid
                thumb_name = f"thumb_{uuid.uuid4()}.jpg"
                thumb_path = os.path.join(os.path.dirname(file_path), thumb_name)
                
                def _d_thumb():
                    with urllib.request.urlopen(thumbnail, timeout=10) as response:
                        with open(thumb_path, 'wb') as f:
                            f.write(response.read())
                
                await asyncio.get_event_loop().run_in_executor(None, _d_thumb)
            except Exception as e:
                print(f"[TG] Failed to download thumbnail: {e}")
                thumb_path = None
        elif thumbnail and os.path.exists(thumbnail):
            thumb_path = thumbnail

        try:
            print(f"[TG] Uploading {clean_name}...")
            
            attributes = []
            
            # Add MIME-specific attributes
            mime_type, _ = mimetypes.guess_type(file_path)
            is_video = mime_type and mime_type.startswith('video')
            is_audio = mime_type and mime_type.startswith('audio')
            
            if is_video:
                from telethon.tl.types import DocumentAttributeVideo
                attributes.append(DocumentAttributeVideo(
                    duration=duration or 0,
                    w=0, h=0, # Unknown dimensions
                    supports_streaming=True
                ))
            elif is_audio:
                from telethon.tl.types import DocumentAttributeAudio
                attributes.append(DocumentAttributeAudio(
                    duration=duration or 0,
                    title=title,
                    performer=artist
                ))
            
            # Always add filename attribute as backup
            if clean_name != os.path.basename(file_path):
                attributes.append(DocumentAttributeFilename(file_name=clean_name))
            
            # Telethon handles parallel upload automatically for large files
            msg = await self.client.send_file(
                self.bin_channel,
                file_path,
                caption=f"Uploaded via mPlay: {clean_name}",
                progress_callback=_progress if progress_callback else None,
                attributes=attributes,
                thumb=thumb_path,
                force_document=False, # Let Telethon decide (Audio/Video vs Document)
                supports_streaming=True
            )
            print(f"[TG] Upload complete! Msg ID: {msg.id}")
            return msg
        except Exception as e:
            print(f"[TG] Upload failed: {e}")
            return None
        finally:
            # Cleanup temp thumbnail
            if thumb_path and thumbnail.startswith("http") and os.path.exists(thumb_path):
                try:
                    os.remove(thumb_path)
                except:
                    pass

    async def get_file_info(self, message_id: int) -> Dict[str, Any]:
        """Fetch metadata, rotating through workers to avoid FloodWait."""
        last_error = None
        
        # Determine start index for round-robin validation
        # We start with a random worker to distribute check load
        import random
        start_idx = random.randint(0, len(self.clients) - 1)
        
        for i in range(len(self.clients)):
            idx = (start_idx + i) % len(self.clients)
            client = self.clients[idx]
            
            try:
                # Try fetching message
                message = await client.get_messages(self.bin_channel, ids=message_id)
                
                # If not found, maybe channel cache is stale for this worker?
                if not message:
                    try:
                        await client.get_input_entity(self.bin_channel)
                        message = await client.get_messages(self.bin_channel, ids=message_id)
                    except:
                        pass

                if message and message.media:
                    return {
                        "file_name": message.file.name or f"file_{message_id}.mp3",
                        "mime_type": message.file.mime_type or mimetypes.guess_type(message.file.name or "")[0] or "audio/mpeg",
                        "file_size": message.file.size
                    }
            except Exception as e:
                # Log usage only if it's not a common "message not found" logic error
                # print(f"[TG] Worker {idx} check failed: {e}")
                last_error = e
        
        # If we get here, all workers failed
        print(f"[TG] Error get_file_info(id={message_id}) failed on ALL workers. Last error: {last_error}")
        raise FileNotFound(f"Message {message_id} not found")


    async def stream_file(self, message_id: int, offset: int = 0, limit: int = 0) -> AsyncGenerator[bytes, None]:
        """
        Load-Balanced Streamer.
        
        Optimized for Client-Side Parallelism (e.g. Mobile Proxy).
        Requests are distributed across the Worker Pool.
        """
        try:
            # 1. Round-Robin / Random Worker Selection
            # This balances the load when the client makes parallel requests.
            import random
            worker_idx = random.randint(0, self.pool_size - 1)
            client = self.clients[worker_idx]
            
            # print(f"[STREAM] Request: Offset={offset}, Limit={limit} | Worker {worker_idx}")

            # 2. Fetch Media (Worker Specific)
            try:
                message = await client.get_messages(self.bin_channel, ids=message_id)
            except Exception as e:
                print(f"[STREAM] Worker {worker_idx} failed metadata: {e}. trying others...")
                # Try finding ANY worker that can see the message
                message = None
                for i in range(len(self.clients)):
                    if i == worker_idx: continue
                    try:
                        msg_check = await self.clients[i].get_messages(self.bin_channel, ids=message_id)
                        if msg_check and msg_check.media:
                            client = self.clients[i]
                            message = msg_check
                            print(f"[STREAM] Failover success: Switched to Worker {i}")
                            break
                    except:
                        continue

            if not message or not message.media:
                raise FileNotFound(f"Message {message_id} not found")

            # 3. Stream
            chunk_size = 1024 * 1024  # 1MB
            file_size = message.file.size
            if limit <= 0:
                limit = file_size - offset

            remaining = limit
            current_pos = offset
            
            async for chunk in client.iter_download(
                message.media,
                offset=current_pos,
                limit=remaining,
                chunk_size=chunk_size,
                request_size=512 * 1024,
            ):
                if not chunk: break
                yield chunk
                remaining -= len(chunk)
                current_pos += len(chunk)
                if remaining <= 0: break

        except Exception as e:
            print(f"[STREAM ERROR] {e}")
            raise

tg_client = TelegramClientWrapper()