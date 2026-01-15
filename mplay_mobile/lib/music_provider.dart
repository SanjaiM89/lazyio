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
    _audioPlayer.setLoopMode(LoopMode.all); // Enable looping by default
    
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && _playlist.isNotEmpty && index < _playlist.length) {
        _currentIndex = index;
        _currentSong = _playlist[index];
        notifyListeners();
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
    final bool isSamePlaylist = _playlist.length == playlist.length && 
                                _playlist.every((s) => playlist.any((p) => p.id == s.id));
    
    _playlist = playlist;
    _currentSong = song;
    _currentIndex = _playlist.indexWhere((s) => s.id == song.id);
    notifyListeners();

    try {
      if (!isSamePlaylist || _audioPlayer.audioSource == null) {
        // Build playlist source for pre-buffering
        final sources = _playlist.map((s) {
          return AudioSource.uri(
            Uri.parse(ApiService.getStreamUrl(s.id)),
            tag: MediaItem(
              id: s.id,
              title: s.title,
              artist: s.artist,
              artUri: s.coverArt != null ? Uri.parse(s.coverArt!) : null,
              album: s.album,
            ),
          );
        }).toList();

        final playlistSource = ConcatenatingAudioSource(children: sources);
        await _audioPlayer.setAudioSource(playlistSource, initialIndex: _currentIndex);
      } else {
        // Just seek if playlist is same
        await _audioPlayer.seek(Duration.zero, index: _currentIndex);
      }
      
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
    if (_audioPlayer.hasNext) {
      await _audioPlayer.seekToNext();
    } else if (_playlist.isNotEmpty) {
      // Loop manually if needed (though LoopMode.all handles it)
      await _audioPlayer.seek(Duration.zero, index: 0);
    }
  }

  Future<void> previous() async {
    if (_audioPlayer.hasPrevious) {
      await _audioPlayer.seekToPrevious();
    } else if (_playlist.isNotEmpty) {
      await _audioPlayer.seek(Duration.zero, index: _playlist.length - 1);
    }
  }
}
