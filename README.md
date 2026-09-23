# Lazyio - Self-Hosted AI Music Player

**Lazyio** is a modern, self-hostable music streaming application that combines the aesthetics of Apple Music/Spotify with the freedom of self-hosting. It leverages **Telegram** for unlimited free cloud storage and **Mistral AI** for intelligent, unique music recommendations.

![Lazyio Logo](lazyio_logo.png)

## Downloads (v1.0.0)

Prebuilt installers and packages are published on the releases page:

https://github.com/SanjaiM89/lazyio/releases/tag/v1.0.0

| Platform | File | Install notes |
|---|---|---|
| Windows (x64) | `lazyio-1.0.0-windows-x86_64-setup.exe` | Run the installer (NSIS). Requires no extra setup. |
| macOS (Apple Silicon) | `lazyio-1.0.0-macos-arm64.dmg` | Open the disk image and drag Lazyio to Applications. Ad-hoc signed: on first launch, right-click the app and choose Open. |
| Linux (any distro) | `lazyio-1.0.0-linux-x86_64.AppImage` | `chmod +x` the file and run it. Qt is bundled, no dependencies needed. |
| Linux (Debian/Ubuntu) | `lazyio_1.0.0_amd64.deb` | `sudo dpkg -i lazyio_1.0.0_amd64.deb`. Requires system Qt 6 libraries (see release notes). |
| Linux (Arch, portable) | `lazyio-1.0.0-linux-x86_64.tar.gz` | Extract to `/usr` (`tar -xzf … -C /`). Install Qt 6 via pacman (`qt6-base qt6-declarative qt6-multimedia qt6-websockets qt6-svg`). |
| Android | `mplay-1.0.0-android.apk` | Sideload the APK (release build signed with debug keys). Point the app at your backend URL on first launch. |
| iOS | `mplay-1.0.0-ios-unsigned.ipa` | Unsigned build. Re-sign and sideload with AltStore or Sideloadly (free Apple ID, refresh every 7 days). |

New releases are cut by pushing a version tag (`git tag vX.Y.Z && git push origin vX.Y.Z`), which builds and attaches every artifact automatically.

## Features

*   **Premium UI**: Glassmorphism design inspired by Apple Music and Spotify.
*   **Unlimited Storage**: Uses a Telegram channel as a robust backend for storing audio files (auto-indexed on startup).
*   **AI Recommendations**: Integrated with **Mistral AI** to suggest *new* songs based on your listening history (deduplicated recommendations).
*   **Spotify-style audio analysis**: Every track is analyzed with librosa (BPM, instrumentalness, lo-fi score, energy, valence) and indexed with FAISS similarity vectors, so autoplay and "similar songs" match by actual sound.
*   **Language-aware search**: Automatic language detection (Tamil, Hindi, Telugu and more) with intent parsing, so searching "tamil songs" filters to Tamil tracks.
*   **Hybrid recommendations**: Content similarity blended with next-track co-occurrence from your play history, plus a taste profile that learns your languages/genres and decays weekly.
*   **Synced Lyrics**: Line-by-line lyrics from [LRCLIB](https://lrclib.net) on web and mobile (Flutter) — auto-follow while playing and click-a-line-to-seek. Each track is looked up once and stored in MongoDB, so repeat plays never hit the lyrics service again.
*   **Telegram Library**: Set `TELEGRAM_SOURCE_CHANNEL` in `.env` — the backend scans the channel, indexes tracks in MongoDB, and groups same-named music into albums/playlists.
*   **Live Library**: Real-time updates across devices using WebSockets.
*   **Playlist Management**: Create playlists, add/rename/delete songs with a native feel.
*   **Background Playback**: Full audio service support with notification controls.
*   **Cross-Platform**: React web player, Qt desktop client (Windows/macOS/Linux) and Flutter mobile app (Android/iOS).

## Architecture

```
lazyio/
  BackEnd/        Python/FastAPI server (uvicorn). MongoDB via Motor.
                  Telegram storage via Telethon, Mistral AI recommendations,
                  librosa audio analysis + FAISS similarity, LRCLIB lyrics.
  FrontEnd/       React + Vite web player (Sonance UI).
  Desktop/        Qt 6 / QML desktop client (same backend API).
  mplay_mobile/   Flutter app (Android, iOS, Linux, Web).
  .github/        CI: release pipeline building all installers on version tags.
```

How the pieces fit together:

1.  **Server (Backend)**: Built with **Python (FastAPI)**.
    *   **Database**: MongoDB (song metadata, playlists, history, lyrics cache, audio descriptors, taste profile).
    *   **Storage**: Telegram (via Telethon) - uploads/retrieves files.
    *   **AI**: Mistral API (recommendation logic) + local audio analysis (librosa) and FAISS similarity search.
2.  **Web player (Frontend)**: Built with **React + Vite**. Talks to the backend REST API.
3.  **Desktop client**: Built with **Qt 6 / QML**. Talks to the same backend REST API.
4.  **Mobile app**: Built with **Flutter**. Talks to the same backend REST API.

## Getting Started

### Prerequisites

*   [Python 3.10+](https://www.python.org/downloads/)
*   [MongoDB](https://www.mongodb.com/try/download/community) (Local or Atlas)
*   [Node.js](https://nodejs.org/) (for the web player)
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (for the mobile app)
*   Qt 6 + CMake + Ninja (for the desktop client, optional)
*   **Telegram Credentials**: API ID, API Hash (from [my.telegram.org](https://my.telegram.org)) and Bot Token.
*   **Mistral API Key**: (Optional, for AI features).

### 1. Backend Setup

1.  Navigate to the backend directory:
    ```bash
    cd BackEnd
    ```

2.  Create and activate a virtual environment:
    ```bash
    python3 -m venv venv
    source venv/bin/activate  # Linux/Mac
    # venv\Scripts\activate   # Windows
    ```

3.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```

4.  Configure Environment Variables:
    Create a `config.env` file in `BackEnd/` with the following:
    ```env
    API_ID=your_telegram_api_id
    API_HASH=your_telegram_api_hash
    BOT_TOKEN=your_telegram_bot_token
    TELEGRAM_API_ID=your_telegram_api_id
    TELEGRAM_API_HASH=your_telegram_api_hash
    TELEGRAM_BOT_TOKEN=your_telegram_bot_token
    TELEGRAM_SOURCE_CHANNEL=@your_channel_username
    MONGO_DB_URI=mongodb://localhost:27017
    MISTRAL_API_KEY=your_mistral_api_key
    ```

5.  Run the server:
    ```bash
    python start.py
    ```
    *Server will start at `http://0.0.0.0:8000`*

6.  (Optional) Backfill audio analysis and language labels for an existing library:
    ```bash
    curl -X POST http://localhost:8000/api/admin/detect-languages
    curl -X POST http://localhost:8000/api/admin/analyze-library \
      -H 'Content-Type: application/json' -d '{"limit": 50}'
    ```

### 1b. Backend Setup (Docker - Faster)

Instead of setting up Python manually, you can use the pre-built Docker image.

1.  **Create a Config File**:
    Create a file named `config.env` and populate it with your credentials (see step 4 of manual setup above).

2.  **Pull and Run**:
    ```bash
    # Pull the latest image
    docker pull sanjaim86/lazyio:latest

    # Run the container (background mode)
    docker run -d \
      --name lazyio-backend \
      --env-file config.env \
      -p 8000:8000 \
      sanjaim86/lazyio:latest
    ```
    *The backend is now running on port 8000.*

### 2. Web Player Setup

1.  Navigate to the web directory:
    ```bash
    cd FrontEnd
    ```

2.  Install dependencies and start the dev server:
    ```bash
    npm install
    npm run dev
    ```
    The player talks to the backend API (default `http://localhost:8000`).

### 3. Desktop Client Setup (Optional)

Requires Qt 6 (Core, Gui, Qml, Quick, QuickControls2, Multimedia, Network, WebSockets, Widgets, Svg), CMake 3.21+ and Ninja.

```bash
cd Desktop
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/lazyio
```

### 4. Mobile App Setup

1.  Navigate to the mobile app directory:
    ```bash
    cd mplay_mobile
    ```

2.  Update Configuration:
    Open `lib/constants.dart` and update `baseUrl`:
    ```dart
    // For Physical Device: Use your PC's local IP (e.g., 192.168.1.5)
    // For Emulator: Use 'http://10.0.2.2:8000'
    const String baseUrl = 'http://192.168.1.x:8000';
    ```

3.  Install dependencies:
    ```bash
    flutter pub get
    ```

4.  Run the app:
    ```bash
    flutter run
    ```

5.  Build APK (Release):
    ```bash
    flutter build apk --release
    ```
    *Output: `build/app/outputs/flutter-apk/app-release.apk`*

## Tech Stack

*   **Web player**: React, Vite, Axios, Fuse.js
*   **Desktop**: Qt 6, QML, CMake
*   **Mobile**: Flutter, Provider, Just Audio, Glassmorphism
*   **Backend**: Python, FastAPI, Uvicorn, Motor (Async MongoDB), librosa, FAISS
*   **External APIs**: Telegram (Telethon), Mistral AI, LRCLIB

## Acknowledgements

*   **[fyaz05/FileToLink](https://github.com/fyaz05/FileToLink)**: Huge thanks to this repository! A significant portion of the Telegram storage logic and backend code was adapted from this project. It provided the core foundation for handling Telegram file uploads and streaming.

## License

This project is open-source and available for personal use.
