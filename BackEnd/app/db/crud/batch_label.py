"""Batch auto-labeling utility for Lazyio MongoDB song library.

Applies updated transliteration detection, artist/genre hints, and vocal signals
to automatically tag language for all tracks in MongoDB where language is missing.
Uses MongoDB bulk_write for high throughput.
"""

import asyncio
import logging
from collections import Counter
from pymongo import UpdateOne

from app.db.connection import songs_collection
from app.services.language import detect_language, normalize_language
from app.db.crud.search_engine import mark_search_index_dirty

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("BatchAutoLabel")


async def run_batch_autolabel():
    logger.info("Starting fast bulk auto-labeling scan...")
    total = await songs_collection.count_documents({})
    logger.info(f"Total songs in collection: {total}")

    bulk_ops = []
    updated_count = 0
    language_counts = Counter()

    async for song in songs_collection.find({}):
        sid = song["_id"]
        current_lang = song.get("language")
        current_source = song.get("language_source", "auto")

        # Skip manual labels
        if current_lang and current_source == "manual":
            language_counts[current_lang] += 1
            continue

        title = song.get("title")
        artist = song.get("artist")
        album = song.get("album")
        genre = song.get("genre")

        detected_lang, detail = detect_language(title, artist, album, genre)

        if detected_lang and detected_lang != current_lang:
            bulk_ops.append(
                UpdateOne(
                    {"_id": sid},
                    {"$set": {"language": detected_lang, "language_source": "auto"}}
                )
            )
            updated_count += 1
            language_counts[detected_lang] += 1
        elif current_lang:
            language_counts[current_lang] += 1

        if len(bulk_ops) >= 500:
            await songs_collection.bulk_write(bulk_ops)
            logger.info(f"Flushed batch of {len(bulk_ops)} updates...")
            bulk_ops = []

    if bulk_ops:
        await songs_collection.bulk_write(bulk_ops)
        logger.info(f"Flushed final batch of {len(bulk_ops)} updates...")

    if updated_count > 0:
        mark_search_index_dirty()

    logger.info(f"Auto-labeling complete! Updated {updated_count} songs.")
    logger.info(f"Language breakdown across library: {dict(language_counts)}")
    return updated_count, dict(language_counts)


if __name__ == "__main__":
    asyncio.run(run_batch_autolabel())
