import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'models.dart';
import 'api_service.dart';

import 'package:just_audio_background/just_audio_background.dart';

class MusicProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  // ... existing fields ...
  Song? _currentSong;
  bool _isPlaying = false;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  MusicProvider() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
      
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });

    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    
    _audioPlayer.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;

  Future<void> playSong(Song song, List<Song> playlist) async {
    _currentSong = song;
    _playlist = playlist;
    _currentIndex = _playlist.indexWhere((s) => s.id == song.id);
    notifyListeners();

    try {
      final url = ApiService.getStreamUrl(song.id);
      
      // Use AudioSource to provide metadata for background playback
      final source = AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(
          id: song.id,
          title: song.title,
          artist: song.artist,
          artUri: song.coverArt != null ? Uri.parse(song.coverArt!) : null,
          album: song.album,
        ),
      );

      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
      ApiService.recordPlay(song.id);
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }
  
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex < _playlist.length - 1) {
      await playSong(_playlist[_currentIndex + 1], _playlist);
    }
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex > 0) {
      await playSong(_playlist[_currentIndex - 1], _playlist);
    }
  }
}
