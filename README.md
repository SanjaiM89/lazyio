# Lazyio - Self-Hosted AI Music Player 🦥🎶

**Lazyio** is a modern, self-hostable music streaming application that combines the aesthetics of Apple Music/Spotify with the freedom of self-hosting. It leverages **Telegram** for unlimited free cloud storage and **Mistral AI** for intelligent, unique music recommendations.

![Lazyio Logo](lazyio_logo.png)

## ✨ Features

*   **Premium UI**: Glassmorphism design inspired by Apple Music and Spotify.
*   **Unlimited Storage**: Uses Telegram as a robust, specialized backend for storing audio files.
*   **AI Recommendations**: Integrated with **Mistral AI** to suggest *new* songs based on your listening history (deduplicated recommendations).
*   **YouTube Downloader**: Download individual songs or entire playlists directly from YouTube.
*   **Live Library**: Real-time updates across devices using WebSockets.
*   **Playlist Management**: Create playlists, add/rename/delete songs with a native feel.
*   **Background Playback**: Full audio service support with notification controls.
*   **Cross-Platform**: Built with Flutter (Android, iOS, Linux, Web).

## 🏗️ Architecture

The project consists of two main parts:

1.  **Mobile App (Frontend)**: Built with **Flutter**. Handles UI, audio playback, and user interaction.
2.  **Server (Backend)**: Built with **Python (FastAPI)**.
    *   **Database**: MongoDB (stores song metadata, playlists, user history).
    *   **Storage**: Telegram (via Telethon) - uploads/retrieves files.
    *   **AI**: Mistral API (for recommendation logic).

## 🚀 Getting Started

### Prerequisites

*   [Flutter SDK](https://docs.flutter.dev/get-started/install)
*   [Python 3.10+](https://www.python.org/downloads/)
*   [MongoDB](https://www.mongodb.com/try/download/community) (Local or Atlas)
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
    MONGO_DB_URI=mongodb://localhost:27017
    MISTRAL_API_KEY=your_mistral_api_key
    ```

5.  Run the server:
    ```bash
    python main.py
    ```
    *Server will start at `http://0.0.0.0:8000`*

### 2. Mobile App Setup

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

## 🛠️ Tech Stack

*   **Frontend**: Flutter, Provider, Just Audio, Glassmorphism
*   **Backend**: Python, FastAPI, Uvicorn, Motor (Async MongoDB)
*   **External APIs**: Telegram (Telethon), Mistral AI, YouTube (yt-dlp)

## 📄 License

This project is open-source and available for personal use.
