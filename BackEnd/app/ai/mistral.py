import os
import httpx
from typing import List, Dict
import asyncio
import random
from collections import Counter

MISTRAL_API_KEY = os.getenv("MISTRAL_API_KEY", "5w4rvCocyO2ZWXDUw974C8BbGdc4MJiB")
MISTRAL_API_URL = "https://api.mistral.ai/v1/chat/completions"

# Rate limiting - free tier is 1 request/second
_last_request_time = 0
_api_failures = 0  # Track consecutive API failures


async def _rate_limit():
    """Ensure at least 1.5 seconds between requests (safe margin for free tier)"""
    global _last_request_time
    import time

    now = time.time()
    wait_time = max(0, 1.5 - (now - _last_request_time))
    if wait_time > 0:
        await asyncio.sleep(wait_time)
    _last_request_time = time.time()


async def _call_mistral(prompt: str, temperature: float = 0.7) -> str:
    """Make a rate-limited call to Mistral API"""
    global _api_failures
    await _rate_limit()

    headers = {
        "Authorization": f"Bearer {MISTRAL_API_KEY}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": "mistral-tiny",  # Cheapest model for free tier
        "messages": [{"role": "user", "content": prompt}],
        "temperature": temperature,
        "max_tokens": 200,  # Limit tokens to save quota
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                MISTRAL_API_URL, json=payload, headers=headers, timeout=15.0
            )
            if response.status_code == 200:
                _api_failures = 0  # Reset on success
                data = response.json()
                return data["choices"][0]["message"]["content"]
            elif response.status_code == 429:  # Rate limit
                _api_failures += 1
                print(f"[AI] Rate limited! Failure count: {_api_failures}")
                return ""
            else:
                _api_failures += 1
                print(f"Mistral API Error: {response.status_code} - {response.text}")
                return ""
    except Exception as e:
        _api_failures += 1
        print(f"Error calling Mistral API: {e}")
        return ""


def _get_time_of_day_context() -> str:
    from datetime import datetime

    hour = datetime.now().hour
    if 5 <= hour < 12:
        return "Morning (Energetic, Focus, Upbeat, Wake up)"
    elif 12 <= hour < 17:
        return "Afternoon (Productive, Steady, Pop, Driving)"
    elif 17 <= hour < 21:
        return "Evening (Relaxing, Groove, Chill, Unwind)"
    else:
        return "Late Night (Ambient, Deep, Soothing, Sleepy)"


def _sync_ddg_search(query: str):
    try:
        from duckduckgo_search import DDGS

        with DDGS() as ddgs:
            return list(ddgs.text(query, max_results=2))
    except ImportError:
        print("[AI] duckduckgo-search not installed")
        return []
    except Exception as e:
        print(f"[AI] DDG Sync error: {e}")
        return []


async def _get_web_context(artist: str, title: str) -> str:
    if not artist or not title or artist == "Unknown" or title == "Unknown":
        return ""
    query = f'"{artist}" "{title}" song genre music style review'
    try:
        loop = asyncio.get_running_loop()
        results = await loop.run_in_executor(None, _sync_ddg_search, query)
        context = ""
        for r in results:
            context += r.get("body", "") + " "
        return context[:400]
    except Exception as e:
        print(f"[AI] DuckDuckGo search failed: {e}")
        return ""


def _calculate_similarity_score(
    song: Dict, liked_songs: List[Dict], all_songs: List[Dict]
) -> float:
    """
    Calculate recommendation score for a song using multiple signals.
    Higher score = higher recommendation priority.
    """
    score = 0.0

    song_artist = song.get("artist", "").lower()
    liked_artists = Counter([s.get("artist", "").lower() for s in liked_songs])

    if song_artist in liked_artists:
        score += 30 * liked_artists[song_artist]

    for liked_artist, count in liked_artists.items():
        if liked_artist in song_artist or song_artist in liked_artist:
            score += 15 * count

    song_album = song.get("album", "").lower()
    liked_albums = Counter([s.get("album", "").lower() for s in liked_songs])

    if song_album in liked_albums and song_album != "youtube":
        score += 15 * liked_albums[song_album]

    song_title_words = set(song.get("title", "").lower().split())
    liked_title_words = Counter()
    for s in liked_songs:
        for word in s.get("title", "").lower().split():
            if len(word) > 3:
                liked_title_words[word] += 1

    for word in song_title_words:
        if word in liked_title_words:
            idf = 1.0 / (liked_title_words[word] + 1)
            score += 10 * idf

    song_duration = song.get("duration", 200)
    avg_liked_duration = sum(s.get("duration", 200) for s in liked_songs) / max(
        len(liked_songs), 1
    )
    duration_diff = abs(song_duration - avg_liked_duration)
    if duration_diff < 60:
        score += 5
    elif duration_diff < 120:
        score += 2

    unique_artists = len(set(s.get("artist", "").lower() for s in liked_songs))
    if song_artist not in liked_artists and unique_artists > 3:
        score += 3

    try:
        song_index = next(
            i for i, s in enumerate(all_songs) if s.get("id") == song.get("id")
        )
        recency_score = min(5, len(all_songs) - song_index) / 5
        score += recency_score * 2
    except StopIteration:
        pass

    play_count = song.get("play_count", 0)
    if play_count > 0:
        if play_count < 5:
            score += play_count * 2
        elif play_count < 20:
            score += 10 + (play_count - 5) * 0.5
        else:
            score += 20

    return score


def _fallback_recommendations(
    current_song: Dict,
    liked_songs: List[Dict],
    all_songs: List[Dict],
    exclude_ids: set = None,
    limit: int = 10,
) -> List[Dict]:
    """
    Fallback recommendation algorithm when LLM API is unavailable.
    Uses content-based + collaborative filtering similar to YouTube Music.
    """
    if exclude_ids is None:
        exclude_ids = set()

    exclude_ids.add(current_song.get("id"))
    candidates = [s for s in all_songs if s.get("id") not in exclude_ids]

    if not candidates:
        return []

    if not liked_songs:
        liked_songs = [current_song]

    scored = []
    for song in candidates:
        score = _calculate_similarity_score(song, liked_songs, all_songs)
        scored.append((song, score))

    scored.sort(key=lambda x: x[1], reverse=True)

    top_candidates = scored[: min(limit * 3, len(scored))]
    if len(top_candidates) > limit:
        weights = [max(1, s[1]) for s in top_candidates]
        total_weight = sum(weights)
        normalized_weights = [w / total_weight for w in weights]

        selected = []
        remaining = list(range(len(top_candidates)))
        for _ in range(min(limit, len(top_candidates))):
            if not remaining:
                break
            r = random.random()
            cumsum = 0
            for i, idx in enumerate(remaining):
                cumsum += normalized_weights[idx]
                if r <= cumsum:
                    selected.append(top_candidates[idx][0])
                    remaining.remove(idx)
                    break

        return selected
    else:
        return [s[0] for s in scored[:limit]]


async def get_music_recommendations(
    current_song: Dict, history: List[Dict], all_songs: List[Dict] = None
) -> List[str]:
    """
    Asks Mistral to recommend songs based on current song and history.
    Falls back to algorithmic recommendations if API fails.
    Returns a list of song titles/artist strings.
    """
    global _api_failures

    # Use fallback if API has failed multiple times
    if _api_failures >= 3:
        print("[AI] Using fallback algorithm (API unavailable)")
        if all_songs:
            recs = _fallback_recommendations(current_song, history, all_songs, limit=5)
            return [
                f"{s.get('title', 'Unknown')} - {s.get('artist', 'Unknown')}"
                for s in recs
            ]
        return []

    history_str = "\n".join(
        [
            f"- {s.get('title', 'Unknown')} by {s.get('artist', 'Unknown')} (Played {s.get('play_count', 0)} times)"
            for s in history[-5:]
        ]
    )
    current_str = f"{current_song.get('title', 'Unknown')} by {current_song.get('artist', 'Unknown')}"

    web_context = await _get_web_context(
        current_song.get("artist", ""), current_song.get("title", "")
    )

    audio_context = ""
    try:
        from app.ai.recommender import audio_recommender

        if all_songs and current_song.get("id"):
            similar_ids = audio_recommender.find_similar(current_song["id"], limit=3)
            similar_songs = [
                s
                for s in all_songs
                if s["id"] in similar_ids and s["id"] != current_song["id"]
            ]
            if similar_songs:
                audio_context = "\nSonically Similar Tracks (Raw Audio Analysis):\n"
                for s in similar_songs:
                    audio_context += f"- {s.get('title')} by {s.get('artist')}\n"
    except Exception as e:
        print(f"[AI] Audio context failed: {e}")

    top_artists = [s.get("artist", "") for s in history if s.get("artist")]
    fav_artist = (
        Counter(top_artists).most_common(1)[0][0] if top_artists else "Mixed Artists"
    )

    time_context = _get_time_of_day_context()

    all_titles = [s.get("title", "").lower() for s in history]
    all_titles.append(current_song.get("title", "").lower())

    prompt = f"""I am building a sophisticated Spotify-style taste profile.
Context: The current time of day is {time_context}.
User Behavior: The user heavily favors {fav_artist}.

Currently playing: {current_str}
Web NLP Data about this song's vibe: {web_context}
{audio_context}

User's recent history:
{history_str}

Based on the raw audio analysis, behavioral data, and time of day, recommend 5 similar songs that fit this exact context and taste profile.
Suggest NEW songs NOT in my history.
Return ONLY "Title - Artist" format, one per line, no numbers."""

    content = await _call_mistral(prompt)
    if content:
        # Filter out any songs that match existing titles
        recommendations = []
        for line in content.split("\n"):
            line = line.strip()
            if line and " - " in line:
                title = line.split(" - ")[0].lower()
                if title not in all_titles:
                    recommendations.append(line)
        return recommendations[:5]

    # Fallback if API returned empty
    print("[AI] API returned empty, using fallback algorithm")
    if all_songs:
        recs = _fallback_recommendations(current_song, history, all_songs, limit=5)
        return [
            f"{s.get('title', 'Unknown')} - {s.get('artist', 'Unknown')}" for s in recs
        ]

    return []


async def generate_ai_playlist(songs: List[Dict]) -> Dict:
    """
    Generate an AI playlist with a creative name based on library songs.
    Falls back to generic naming if API unavailable.
    Returns {"name": "Creative Name", "song_ids": [...]}
    """
    if not songs:
        return {"name": "AI Mix", "song_ids": []}

    # Pick random songs for the playlist (max 10)
    selected = random.sample(songs, min(10, len(songs)))
    song_ids = [s["id"] for s in selected]

    # If API is failing, use fallback naming
    global _api_failures
    if _api_failures >= 3:
        # Generate name from most common artist
        artists = Counter([s.get("artist", "Unknown") for s in selected])
        top_artist = artists.most_common(1)[0][0] if artists else "Unknown"
        name = f"{top_artist} Mix"[:30]
        print(f"[AI] Using fallback playlist name: {name}")
        return {"name": name, "song_ids": song_ids}

    # Generate creative playlist name
    song_list = ", ".join([f"{s.get('title', 'Unknown')}" for s in selected[:5]])

    prompt = f"""Create a creative, catchy playlist name (2-4 words) for a mix containing: {song_list}

Examples: "Late Night Vibes", "Morning Energy", "Sunset Drive", "Chill Mode"

Return ONLY the playlist name, nothing else."""

    name = await _call_mistral(prompt, temperature=0.9)
    if name:
        name = name.strip().strip('"').strip("'")[:30]
    else:
        # Fallback naming
        artists = Counter([s.get("artist", "Unknown") for s in selected])
        top_artist = artists.most_common(1)[0][0] if artists else "Mix"
        name = f"{top_artist} Mix"[:30]

    return {"name": name, "song_ids": song_ids}


async def get_homepage_recommendations(
    all_songs: List[Dict], liked_songs: List[Dict] = None
) -> Dict:
    """
    Generate recommendations for homepage (called hourly).
    Uses liked_songs to personalize AI recommendations.
    Falls back to algorithmic recommendations if API unavailable.
    Returns {"recommendations": [...], "ai_playlist": {...}}
    """
    if not all_songs:
        return {
            "recommendations": [],
            "ai_playlist": {"name": "AI Mix", "song_ids": []},
        }

    # Use liked songs if available, otherwise use random
    if liked_songs and len(liked_songs) > 0:
        # Base recommendations on user's liked songs
        sample_song = random.choice(liked_songs)
        history = liked_songs[:5]
        print(f"[AI] Using {len(liked_songs)} liked songs for personalization")
    else:
        sample_song = random.choice(all_songs) if all_songs else {}
        history = all_songs[:5]
        print("[AI] No liked songs, using random sample")

    # Pass all_songs for fallback
    recommendations = await get_music_recommendations(sample_song, history, all_songs)
    ai_playlist = await generate_ai_playlist(all_songs)

    return {"recommendations": recommendations, "ai_playlist": ai_playlist}


def get_fallback_queue(
    current_song: Dict,
    liked_songs: List[Dict],
    all_songs: List[Dict],
    played_ids: set = None,
    limit: int = 10,
) -> List[Dict]:
    exclude_ids = played_ids or set()
    return _fallback_recommendations(
        current_song, liked_songs, all_songs, exclude_ids, limit
    )
