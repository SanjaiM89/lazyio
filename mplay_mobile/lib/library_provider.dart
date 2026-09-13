import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';

class LibraryProvider with ChangeNotifier {
  List<Song> _songs = [];
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreSongs = true;
  int _currentSongPage = 1;
  String? _error;

  static const int _pageSize = 50;

  List<Song> get songs => _songs;
  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreSongs => _hasMoreSongs;
  String? get error => _error;

  bool _isInitialized = false;

  Future<void> loadData({bool forceRefresh = false}) async {
    if (_isInitialized && !forceRefresh) return;

    if (!_isInitialized) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      await _fetchBoth();
      _error = null;
    } catch (e) {
      print("Error loading library: $e");
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    _currentSongPage = 1;
    _hasMoreSongs = true;
    try {
      await _fetchBoth();
      notifyListeners();
      print("Library refreshed silently");
    } catch (e) {
      print("Error refreshing library: $e");
    }
  }

  Future<void> loadMoreSongs() async {
    if (_isLoadingMore || !_hasMoreSongs) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await ApiService.getSongsPaginated(
        page: _currentSongPage + 1,
        limit: _pageSize,
      );
      final newSongs = page['songs'] as List<Song>;
      final totalPages = page['pages'] as int;

      _songs.addAll(newSongs);
      _currentSongPage++;
      _hasMoreSongs = _currentSongPage < totalPages;
      _error = null;
    } catch (e) {
      print("Error loading more songs: $e");
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _fetchBoth() async {
    try {
      final results = await Future.wait([
        ApiService.getSongsPaginated(page: 1, limit: _pageSize),
        ApiService.getPlaylists(),
      ]);

      final songPage = results[0] as Map<String, dynamic>;
      _songs = songPage['songs'] as List<Song>;
      final totalPages = songPage['pages'] as int;
      _currentSongPage = 1;
      _hasMoreSongs = _currentSongPage < totalPages;

      // Parse playlists
      final rawPlaylists = results[1] as List<dynamic>;
      _playlists = rawPlaylists.map((json) {
        if (json is Map<String, dynamic>) {
          return Playlist.fromJson(json);
        } else {
          print("WARNING: unexpected playlist item type: ${json.runtimeType} -> $json");
          return Playlist(id: 'error', name: 'Error', songCount: 0, songIds: []);
        }
      }).toList();
      _playlists.removeWhere((pl) => pl.id == 'error');

    } catch (e, stack) {
      print("Exception in _fetchBoth: $e");
      print(stack);
      rethrow;
    }
  }
}
