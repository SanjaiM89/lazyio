import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';

class LibraryProvider with ChangeNotifier {
  List<Song> _songs = [];
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  String? _error;

  List<Song> get songs => _songs;
  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;
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
    try {
      await _fetchBoth();
      notifyListeners();
      print("Library refreshed silently");
    } catch (e) {
      print("Error refreshing library: $e");
    }
  }

  Future<void> _fetchBoth() async {
    try {
      final results = await Future.wait([
        ApiService.getSongs(),
        ApiService.getPlaylists(),
      ]);

      print("Songs type: ${results[0].runtimeType}");
      print("Playlists type: ${results[1].runtimeType}");
      if ((results[1] as List).isNotEmpty) {
        print("First playlist item type: ${results[1][0].runtimeType}");
        print("First playlist item: ${results[1][0]}");
      }

      _songs = results[0] as List<Song>;
      
      // Parse playlists
      final rawPlaylists = results[1] as List<dynamic>;
      _playlists = rawPlaylists.map((json) {
        if (json is Map<String, dynamic>) {
          return Playlist.fromJson(json);
        } else {
          print("WARNING: unexpected playlist item type: ${json.runtimeType} -> $json");
          // Try to handle or skip
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
