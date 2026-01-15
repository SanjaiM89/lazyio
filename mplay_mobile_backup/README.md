# Running the mPlay Mobile App

This folder `mplay_mobile` contains a complete Flutter application that mirrors the web functionalities of mPlay.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- Android Studio / VS Code with Flutter extensions.
- An Android Emulator or Physical Device.

## Setup

1. **Navigate to the directory:**
   ```bash
   cd mplay_mobile
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Backend URL:**
   Open `lib/constants.dart` and update `baseUrl` and `wsUrl`.
   - **Android Emulator:** Use `http://10.0.2.2:8000` (points to host machine localhost).
   - **Physical Device:** Use your PC's LAN IP (e.g., `http://192.168.1.5:8000`).
   - **iOS Simulator:** Use `http://localhost:8000`.

   ```dart
   // lib/constants.dart
   const String baseUrl = 'http://10.0.2.2:8000'; 
   const String wsUrl = 'ws://10.0.2.2:8000/ws';
   ```

## Running the App

```bash
flutter run
```

## Features Implemented

- **Glassmorphic UI**: Matches the dark/glass web theme.
- **Home Dashboard**: Recently Played, AI Playlist, Recommendations.
- **Library**: Searchable song list.
- **Player**: Full-screen player with seek bar and mini-player.
- **YouTube**: Paste link, download, and view task progress (with auto-polling).
- **Upload**: File picker for uploading songs.
- **Real-time**: Updates library automatically when songs are added/uploaded via WebSockets.
