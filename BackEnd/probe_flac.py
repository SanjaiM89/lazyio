"""Probe a Telegram audio file's real codec parameters.

Downloads the head (and optionally full file) of msg 28629
('Ishaqzaade - Violin Version') and reports FLAC STREAMINFO fields,
ID3 prefix presence, and ffprobe decode errors.
"""
import asyncio
import struct
import subprocess
import sys

MSG_ID = int(sys.argv[1]) if len(sys.argv) > 1 else 28629
FULL = len(sys.argv) > 2 and sys.argv[2] == "full"

sys.path.insert(0, ".")
from app.services.telegram import telegram_client


def parse_flac(head: bytes):
    out = {}
    pos = 0
    if head[:3] == b"ID3":
        out["id3_prefix"] = True
        # ID3v2 header: 10 bytes, size is synchsafe @ 6:10
        size = 0
        for b in head[6:10]:
            size = (size << 7) | (b & 0x7F)
        pos = 10 + size
        out["id3_size"] = size
    else:
        out["id3_prefix"] = False
    if head[pos:pos + 4] != b"fLaC":
        out["error"] = f"no fLaC marker at {pos}, got {head[pos:pos+4]!r}"
        return out
    out["flac_offset"] = pos
    p = pos + 4
    # metadata blocks: 1 byte header (last flag + type), 3 byte length
    while p + 4 <= len(head):
        last = head[p] & 0x80
        btype = head[p] & 0x7F
        blen = int.from_bytes(head[p + 1:p + 4], "big")
        if btype == 0:  # STREAMINFO, 34 bytes
            si = head[p + 4:p + 4 + 34]
            if len(si) < 34:
                out["error"] = "truncated STREAMINFO"
                return out
            out["min_block"] = int.from_bytes(si[0:2], "big")
            out["max_block"] = int.from_bytes(si[2:4], "big")
            out["min_frame"] = int.from_bytes(si[4:7], "big")
            out["max_frame"] = int.from_bytes(si[7:10], "big")
            bits = int.from_bytes(si[10:18], "big")
            out["sample_rate"] = (bits >> 44) & 0xFFFFF
            out["channels"] = ((bits >> 41) & 0x7) + 1
            out["bits_per_sample"] = ((bits >> 36) & 0x1F) + 1
            out["total_samples"] = bits & 0xFFFFFFFFF
            out["md5"] = si[18:34].hex()
        p += 4 + blen
        if last or btype == 0 and False:
            pass
        if last:
            break
    if "sample_rate" not in out:
        out["error"] = "STREAMINFO not found in first bytes"
    return out


async def main():
    info = await telegram_client.file_info(MSG_ID)
    print("file_name:", info.get("file_name"))
    print("file_size:", info.get("file_size"))
    print("mime_type:", info.get("mime_type"))

    head = b""
    async for chunk in telegram_client.stream_file(
        MSG_ID, offset=0, limit=65536,
        media=info["media"], file_size=info["file_size"],
    ):
        head += chunk
        if len(head) >= 65536:
            break
    print("head bytes:", len(head))
    print("first 4:", head[:4])
    for k, v in parse_flac(head).items():
        print(f"flac.{k} =", v)

    if FULL:
        path = f"/tmp/probe-{MSG_ID}.flac"
        with open(path, "wb") as f:
            async for chunk in telegram_client.stream_file(
                MSG_ID, offset=0, limit=info["file_size"],
                media=info["media"], file_size=info["file_size"],
            ):
                f.write(chunk)
        import os
        print("downloaded:", os.path.getsize(path), "expected:", info["file_size"])
        r = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries",
             "stream=codec_name,sample_rate,channels,bits_per_raw_sample,bits_per_sample,sample_fmt",
             "-show_entries", "format=duration,size", "-of", "default=noprint_wrappers=1", path],
            capture_output=True, text=True, timeout=120,
        )
        print("--- ffprobe ---")
        print(r.stdout or "(no output)")
        print(r.stderr or "(no errors)")


asyncio.run(main())
