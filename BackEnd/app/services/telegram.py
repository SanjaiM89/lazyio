"""Telegram storage client (Telethon).

Two modes:
- USER session (preferred, full access): set TELEGRAM_SESSION_STRING
  (generate once with `python generate_session.py`). Can scan channel
  history, stream, upload and delete.
- BOT token (limited): bots cannot call GetHistory/GetDialogs via MTProto,
  so channel scanning and streaming are unavailable. Uploads to a channel
  where the bot is admin still work.

Uses API_ID / API_HASH + SOURCE_CHANNEL from .env / config.env.
"""

import os
from typing import AsyncGenerator, Optional

from app.core.config import settings


class TelegramNotConfigured(Exception):
    pass


class TelegramBotLimitedError(Exception):
    """Raised when an operation needs a user session but only a bot is active."""

    def __init__(self):
        super().__init__(
            "Bot tokens cannot read channel history or stream files via MTProto. "
            "Generate a user session string (python generate_session.py) and set "
            "TELEGRAM_SESSION_STRING in config.env."
        )


class TelegramClientWrapper:
    def __init__(self):
        self.api_id = settings.TELEGRAM_API_ID
        self.api_hash = settings.TELEGRAM_API_HASH
        self.bot_token = settings.TELEGRAM_BOT_TOKEN
        self.session_string = settings.TELEGRAM_SESSION_STRING
        self.source_channel = settings.TELEGRAM_SOURCE_CHANNEL
        self.session_name = settings.TELEGRAM_SESSION
        self._client = None
        self._entity = None
        self.is_bot = False

    @property
    def use_user_session(self) -> bool:
        return bool(self.session_string and str(self.session_string).strip())

    @property
    def configured(self) -> bool:
        has_auth = self.use_user_session or bool(
            self.bot_token and str(self.bot_token).strip()
        )
        return bool(self.api_id and self.api_hash and self.source_channel and has_auth)

    @property
    def can_scan(self) -> bool:
        """Channel history reads need a user session; bots are restricted."""
        return self._client is not None and not self.is_bot

    def _require_config(self):
        if not self.configured:
            raise TelegramNotConfigured(
                "Set TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_SOURCE_CHANNEL "
                "plus either TELEGRAM_SESSION_STRING (preferred, see generate_session.py) "
                "or TELEGRAM_BOT_TOKEN (upload-only) in .env / config.env"
            )

    def _require_user_session(self):
        if self.is_bot or not self.can_scan:
            raise TelegramBotLimitedError()

    async def start(self):
        self._require_config()
        if self._client is not None and self._entity is not None:
            return self._client
        from telethon import TelegramClient

        api_id_int = int(str(self.api_id).strip())
        if self.use_user_session:
            from telethon.sessions import StringSession

            self._client = TelegramClient(
                StringSession(str(self.session_string).strip()),
                api_id_int,
                str(self.api_hash).strip(),
            )
            await self._client.start()
        else:
            self._client = TelegramClient(
                self.session_name, api_id_int, str(self.api_hash).strip()
            )
            await self._client.start(bot_token=str(self.bot_token).strip())

        me = await self._client.get_me()
        self.is_bot = bool(getattr(me, "bot", False))
        mode = "BOT (upload-only)" if self.is_bot else "USER (full access)"
        print(f"[TG] Connected as {getattr(me, 'first_name', '?')} [{mode}]")

        if not self.is_bot:
            # Populate the entity cache: numeric channel IDs need access hashes.
            try:
                await self._client.get_dialogs()
            except Exception as e:
                print(f"[TG] get_dialogs warning (continuing anyway): {e}")

        # resolve source channel (username like @foo or numeric id)
        from telethon.tl.types import PeerChannel

        raw = str(self.source_channel).strip()
        candidates: list = []
        try:
            numeric = int(raw)
            candidates.append(numeric)
            # Web-telegram URLs show group/channel peers as -<id> (e.g. #-4445012381).
            # Users often paste the digits without the minus, which Telethon
            # would mistake for a user ID — so try the negated form too.
            if numeric > 0:
                candidates.append(-numeric)
            # Supergroups/channels need PeerChannel, not a bare (basic-group) chat id.
            chan_id = abs(numeric)
            if chan_id >= 100000:
                candidates.append(PeerChannel(chan_id))
                candidates.append(int(f"-100{chan_id}"))
        except (ValueError, TypeError):
            # Username / invite link — use as-is.
            candidates.append(raw)
        last_error = None
        for target in candidates:
            try:
                entity = await self._client.get_entity(target)
                # Reject plain users: we need a channel/group to index.
                if getattr(entity, "bot", False) and not getattr(
                    entity, "broadcast", False
                ):
                    last_error = ValueError(f"{target!r} resolved to a user, not a channel/group")
                    continue
                self._entity = entity
                break
            except Exception as e:
                last_error = e
                continue
        if self._entity is None:
            print(f"[TG] Could not resolve source channel {raw!r}: {last_error}")
            print("[TG] Hint: for web.telegram.org/k/#-123456 links, include the minus: -123456")
            # Reset so a later call (e.g. POST /api/telegram/scan) retries cleanly.
            try:
                await self._client.disconnect()
            except Exception:
                pass
            self._client = None
            raise last_error
        print(f"[TG] Source resolved: {raw}")
        return self._client

    async def stop(self):
        if self._client is not None:
            try:
                await self._client.disconnect()
            except Exception:
                pass
            self._client = None
            self._entity = None
            self.is_bot = False

    async def _ensure(self):
        if self._client is None:
            await self.start()
        return self._client

    async def iter_messages(self, limit: int = 0):
        client = await self._ensure()
        self._require_user_session()
        entity = self._entity
        async for msg in client.iter_messages(entity, limit=limit or None):
            yield msg

    async def upload_file(
        self,
        file_path: str,
        caption: str = "",
        title: str | None = None,
        artist: str | None = None,
        duration: int = 0,
    ):
        """Upload a local file to the source channel. Returns sent message."""
        import mimetypes
        from telethon.tl.types import DocumentAttributeAudio, DocumentAttributeVideo

        client = await self._ensure()
        mime, _ = mimetypes.guess_type(file_path)
        attrs = []
        if mime and mime.startswith("audio"):
            attrs.append(
                DocumentAttributeAudio(
                    duration=int(duration or 0),
                    title=title,
                    performer=artist,
                )
            )
        elif mime and mime.startswith("video"):
            attrs.append(
                DocumentAttributeVideo(
                    duration=int(duration or 0), w=0, h=0, supports_streaming=True
                )
            )
        msg = await client.send_file(
            self._entity,
            file_path,
            caption=caption or os.path.basename(file_path),
            attributes=attrs or None,
            supports_streaming=True,
        )
        return msg

    async def delete_message(self, message_id: int) -> bool:
        try:
            client = await self._ensure()
            await client.delete_messages(self._entity, [message_id])
            return True
        except Exception as e:
            print(f"[TG] delete failed for {message_id}: {e}")
            return False

    async def get_message(self, message_id: int):
        client = await self._ensure()
        self._require_user_session()
        return await client.get_messages(self._entity, ids=message_id)

    async def stream_file(
        self, message_id: int, offset: int = 0, limit: int = 0
    ) -> AsyncGenerator[bytes, None]:
        client = await self._ensure()
        self._require_user_session()
        message = await client.get_messages(self._entity, ids=message_id)
        if not message or not message.media:
            raise FileNotFoundError(f"Telegram message {message_id} has no media")
        file_size = message.file.size or 0
        if limit <= 0:
            limit = max(file_size - offset, 0)
        remaining = limit
        async for chunk in client.iter_download(
            message.media,
            offset=offset,
            limit=remaining,
            chunk_size=1024 * 256,
            request_size=1024 * 256,
        ):
            if not chunk:
                break
            yield chunk
            remaining -= len(chunk)
            if remaining <= 0:
                break

    async def file_info(self, message_id: int) -> Optional[dict]:
        try:
            message = await self.get_message(message_id)
        except TelegramBotLimitedError:
            raise
        except Exception:
            return None
        if not message or not message.media:
            return None
        return {
            "file_name": message.file.name or f"telegram_{message_id}",
            "mime_type": message.file.mime_type or "application/octet-stream",
            "file_size": message.file.size or 0,
        }


telegram_client = TelegramClientWrapper()
