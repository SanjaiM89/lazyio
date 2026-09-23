"""Integration test verifying language search for Tamil & Sanskrit queries."""

import asyncio
import pytest
from app.db.crud.songs import search_songs
from app.services.language import parse_language_intent


@pytest.mark.anyio
async def test_drift_search():
    print("================ Testing Search Intents ================")
    
    tamil_intent = parse_language_intent("tamil songs")
    print(f"Intent for 'tamil songs': {tamil_intent}")
    assert tamil_intent == "Tamil"
    
    sanskrit_intent = parse_language_intent("sanskrit songs")
    print(f"Intent for 'sanskrit songs': {sanskrit_intent}")
    assert sanskrit_intent == "Sanskrit"

    print("\n================ Executing Search: 'tamil songs' ================")
    tamil_results = await search_songs("tamil songs", limit=10, language=tamil_intent)
    print(f"Found {len(tamil_results)} Tamil songs:")
    for s in tamil_results[:10]:
        print(f" - [{s.get('language')}] {s.get('title')} | Artist: {s.get('artist')} | Genre: {s.get('genre')}")

    print("\n================ Executing Search: 'sanskrit songs' ================")
    sanskrit_results = await search_songs("sanskrit songs", limit=10, language=sanskrit_intent)
    print(f"Found {len(sanskrit_results)} Sanskrit songs:")
    for s in sanskrit_results[:10]:
        print(f" - [{s.get('language')}] {s.get('title')} | Artist: {s.get('artist')} | Genre: {s.get('genre')}")


if __name__ == "__main__":
    asyncio.run(test_drift_search())
