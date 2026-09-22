# Lazyio - Self-Hosted AI Music Player

**Lazyio** is a modern, self-hostable music streaming application that combines the aesthetics of Apple Music/Spotify with the freedom of self-hosting. It leverages **Telegram** for unlimited free cloud storage and **Mistral AI** for intelligent, unique music recommendations.

![Lazyio Logo](lazyio_logo.png)

## What's new in v1.0.0

*   **Spotify-style audio analysis**: every track is analyzed with librosa for BPM, instrumentalness (vocal-band energy), lo-fi score (tape hiss/crackle, muffled top end, squashed dynamics), energy, valence (major/minor mood) and a 13-band MFCC timbre fingerprint. Results are stored per song and indexed in-process with FAISS for instant similarity search.
*   **Language-aware library**: automatic language detection from metadata scripts (Tamil, Hindi, Telugu, Kannada, Malayalam, Punjabi, Bengali and more) with genre-hint fallback. Searching "tamil songs" applies a hard language filter, exactly like Spotify's `language:ta` token. Wrong labels can be corrected per song.
*   **Hybrid recommendations**: FAISS audio similarity blended with next-track co-occurrence mined from play history (cold-start tracks fall back to content-only), plus personal affinity boosts.
*   **Taste profiles**: listening behavior (completions, skips, likes) builds per-language/per-genre affinity weights that decay weekly so recent taste wins.
*   **Qt desktop client**: native `Desktop/` app (Qt 6 + QML) mirroring the web player — lossless playback, synced lyrics, system tray, full library views.
*   **One-command releases**: pushing a `v*` tag builds and publishes installers for every platform (see below).

## Downloads

Prebuilt packages for every platform are published on the release page:

**https://github.com/SanjaiM89/lazyio/releases/tag/v1.0.0**

| Platform | File | Install |
|---|---|---|
| Windows 10/11 (x64) | `lazyio-1.0.0-windows-x86_64-setup.exe` | Run the installer, then launch Lazyio from the Start menu |
| macOS Apple Silicon | `lazyio-1.0.0-macos-arm64.dmg` | Open the dmg, drag Lazyio to Applications (ad-hoc signed: right-click, Open on first launch) |
| Linux (any distro) | `lazyio-1.0.0-linux-x86_64.AppImage` | `chmod +x` the file and run it, Qt is bundled |
| Linux (Debian/Ubuntu) | `lazyio_1.0.0_amd64.deb` | `sudo apt install ./lazyio_1.0.0_amd64.deb` (needs system Qt 6, see release notes) |
| Linux (Arch etc.) | `lazyio-1.0.0-linux-x86_64.tar.gz` | Extract to `/usr`, install Qt 6 via pacman first (see release notes) |
| Android | `mplay-1.0.0-android.apk` | Sideload the APK (release build, debug-signed) |
| iOS | `mplay-1.0.0-ios-unsigned.ipa` | Re-sign with AltStore/Sideloadly using a free Apple ID |

All clients talk to the same self-hosted backend (below) — point them at your server URL.

## Architecture

Monorepo layout:

```
BackEnd/        FastAPI server (Python 3.13), async MongoDB via Motor
FrontEnd/       React + Vite web player (served or static)
Desktop/        Qt 6 + QML desktop client (Linux/Windows/macOS)
mplay_mobile/   Flutter app (Android/iOS, release APK/IPA via CI)
.github/        CI: release pipeline (tag-triggered, all platforms)
```

Backend services (`BackEnd/app/`):

*   `api/` — REST routes: songs, albums, artists, playlists, search, stream, upload, telegram, recommendations, audio analysis, lyrics, websocket.
*   `services/` — Telegram/Stratus storage, metadata (mutagen/Shazam), artwork, lyrics (LRCLIB + Mongo cache), `audio_analysis` (librosa descriptors), `analysis_jobs` (background backfill), `reco` (hybrid recommendations), `language` (script detection + query intent).
*   `ai/` — FAISS content-similarity index (`recommender.py`), Mistral homepage/AI-queue recommendations.
*   `db/crud/` — Mongo access: songs, search engine (in-memory inverted index with typo tolerance + personalization), history, likes, playlists, taste `profile`.
*   Startup (`main.py` lifespan) warms the FAISS index from Mongo, runs the Telegram rescan loop, the hourly AI refresh and the weekly taste-decay job.

Data flow: Telegram channel (audio files) -> channel indexer -> MongoDB (`songs`, `albums`) -> audio/language backfill jobs enrich each track -> search index + FAISS + taste profile serve the clients over REST. Listening signals (`listen`/`skip`/`like`) feed affinities and co-occurrence transitions.

## Features

*   Premium glassmorphism UI inspired by Apple Music and Spotify.
*   Unlimited storage via a Telegram channel (auto-indexed on startup).
*   AI recommendations (Mistral) plus content-based similar tracks (FAISS).
*   Synced lyrics from LRCLIB with click-to-seek, cached in MongoDB.
*   Language-aware search ("tamil songs", "english pop") with result chips.
*   Instrumental / Lo-Fi / language / BPM badges across the web player.
*   Infinite autoplay: similar tracks keep the queue going.
*   Playlists, likes, play history, upload with Telegram sync.
*   System tray + media keys on desktop; background audio on mobile.

## Getting Started (run from source)

### Prerequisites

*   [Python 3.12+](https://www.python.org/downloads/)
*   [MongoDB](https://www.mongodb.com/try/download/community) (local or Atlas)
*   [Node.js 20+](https://nodejs.org/) (web player)
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (mobile, optional)
*   [Qt 6 + CMake + Ninja](https://www.qt.io/download) (desktop, optional)
*   Telegram API ID / API Hash (from [my.telegram.org](https://my.telegram.org)), bot token, source channel
*   Mistral API key (optional, for AI homepage/queue features)
*   `ffmpeg` on PATH (audio analysis + probing)

### 1. Backend

```bash
cd BackEnd
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

Create `BackEnd/config.env`:

```env
TELEGRAM_API_ID=your_api_id
TELEGRAM_API_HASH=your_api_hash
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_SOURCE_CHANNEL=@your_channel_username
DATABASE_URL=mongodb://localhost:27017
DATABASE_NAME=lazyio
MISTRAL_API_KEY=your_mistral_key
```

Run it (auto-restarts when `PORT` changes in `config.env`):

```bash
python start.py
```

Server listens on `http://0.0.0.0:8000` (or `$PORT`). After the first scan, enrich the library:

```bash
# fast, metadata only
curl -X POST http://localhost:8000/api/admin/detect-languages
# slower, audio analysis in the background (BPM, instrumental, lo-fi, vectors)
curl -X POST http://localhost:8000/api/admin/analyze-library \
  -H 'Content-Type: application/json' -d '{"limit": 200}'
```

Useful endpoints: `GET /api/songs/{id}/analysis`, `GET /api/recommend/similar/{id}?same_language=true&explain=true`, `GET /api/profile`, `PATCH /api/songs/{id}/language`.

Docker alternative: `docker build -t lazyio-backend BackEnd/ && docker run -d --env-file BackEnd/config.env -p 8000:8000 lazyio-backend`.

### 2. Web player

```bash
cd FrontEnd
npm install
npm run dev      # dev server
npm run build    # static dist/ for hosting
```

Point `src/api.js` at your backend URL (default `http://localhost:8000`).

### 3. Desktop app

```bash
cd Desktop
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/lazyio
```

### 4. Mobile app

```bash
cd mplay_mobile
flutter pub get
flutter run            # debug on device/emulator
flutter build apk --release   # release APK
```

Set the backend URL in the app settings (emulator: `http://10.0.2.2:8000`, device: your PC's LAN IP).

## Releasing

Pushing a version tag builds every artifact and publishes the GitHub Release automatically:

```bash
git tag v1.2.3 && git push origin v1.2.3
```

Tags with a suffix (`v1.2.3-beta.1`) are published as prereleases. A manual `workflow_dispatch` of the `Release` workflow builds the same artifacts as run artifacts without publishing (useful for testing CI changes).

## Tech Stack

*   Clients: React + Vite (web), Qt 6 + QML (desktop), Flutter + just_audio (mobile)
*   Backend: FastAPI, Uvicorn, Motor, Telethon, librosa, FAISS, Mistral AI
*   Data: MongoDB (metadata, history, lyrics cache, taste profiles), Telegram (audio storage)

## Acknowledgements

*   **[fyaz05/FileToLink](https://github.com/fyaz05/FileToLink)**: a significant portion of the Telegram storage logic and backend code was adapted from this project.

## License

This project is open-source and available for personal use.
