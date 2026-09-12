#!/usr/bin/env python3
"""Generate a Telethon user session string (one-time interactive login).

Why: bot tokens cannot read channel history or stream files via MTProto
(Telegram restricts GetHistory/GetDialogs for bots). The backend needs a
*user* session for channel scanning + streaming.

Usage:
    cd BackEnd
    python generate_session.py

It will ask for API_ID, API_HASH (or read them from config.env/.env),
then your phone number, the login code Telegram sends you, and your
2FA password if set. At the end it prints TELEGRAM_SESSION_STRING —
paste that into config.env. Keep it secret (it grants full account access).
"""

import asyncio
import os
import sys

from dotenv import load_dotenv

load_dotenv(".env")
load_dotenv("config.env")


def _prompt(name: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    value = input(f"{name}{suffix}: ").strip()
    return value or default


async def main() -> int:
    try:
        from telethon import TelegramClient
        from telethon.sessions import StringSession
    except ImportError:
        print("Telethon is not installed. Run: pip install -r requirements.txt")
        return 1

    api_id = _prompt(
        "API_ID", os.getenv("TELEGRAM_API_ID", os.getenv("API_ID", ""))
    )
    api_hash = _prompt(
        "API_HASH", os.getenv("TELEGRAM_API_HASH", os.getenv("API_HASH", ""))
    )
    if not api_id or not api_hash:
        print("API_ID and API_HASH are required (see https://my.telegram.org).")
        return 1

    phone = _prompt("Phone number (international format, e.g. +9198xxxxxxx)")
    if not phone:
        print("Phone number is required.")
        return 1

    client = TelegramClient(StringSession(), int(api_id), api_hash.strip())
    await client.start(phone=phone.strip())
    me = await client.get_me()
    session_string = client.session.save()
    print()
    print(f"Logged in as: {getattr(me, 'first_name', '?')} (@{getattr(me, 'username', '?')})")
    print()
    print("Add this line to config.env (keep it secret!):")
    print()
    print(f"TELEGRAM_SESSION_STRING={session_string}")
    print()
    await client.disconnect()
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
