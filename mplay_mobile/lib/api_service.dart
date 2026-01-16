import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'constants.dart';

class ApiService {
  static Future<List<Song>> getSongs() async {
    final response = await http.get(Uri.parse('$baseUrl/api/songs'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Song.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load songs');
    }
  }

  static Future<Map<String, dynamic>> getHomepage() async {
    final response = await http.get(Uri.parse('$baseUrl/api/home'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load homepage');
    }
  }
  
  static Future<void> recordPlay(String songId) async {
    await http.post(Uri.parse('$baseUrl/api/songs/$songId/play'));
  }

  // YouTube
  static Future<String> submitYoutubeUrl(String url, String quality) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/youtube'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'url': url, 'quality': quality}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['task_id'];
    } else {
      throw Exception('Failed to submit YouTube URL');
    }
  }

  static Future<List<YouTubeTask>> getYoutubeTasks({int page = 1, int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/youtube/tasks?page=$page&limit=$limit'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> tasks = data['tasks'];
      return tasks.map((json) => YouTubeTask.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load tasks');
    }
  }

  static Future<void> cancelYoutubeTask(String taskId) async {
    await http.post(Uri.parse('$baseUrl/api/youtube/cancel/$taskId'));
  }
  
  static Future<void> deleteYoutubeTask(String taskId) async {
      await http.delete(Uri.parse('$baseUrl/api/youtube/tasks/$taskId'));
  }
  
  static Future<void> clearAllYoutubeTasks() async {
    await http.delete(Uri.parse('$baseUrl/api/youtube/tasks'));
  }
  
  static Future<void> uploadFiles(List<String> filePaths) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
    for (String path in filePaths) {
      request.files.add(await http.MultipartFile.fromPath('files', path));
    }
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload files');
    }
  }

  // Playlists
  static Future<List<dynamic>> getPlaylists() async {
    final response = await http.get(Uri.parse('$baseUrl/api/playlists'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['playlists'] ?? [];
    }
    return [];
  }
  
  static Future<String> createPlaylist(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/playlists'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'songs': []}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['id'] ?? '';
    }
    throw Exception('Failed to create playlist');
  }
  
  static Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await http.post(
      Uri.parse('$baseUrl/api/playlists/$playlistId/songs?song_id=$songId'),
    );
  }
  
  static Future<void> deletePlaylist(String playlistId) async {
    await http.delete(Uri.parse('$baseUrl/api/playlists/$playlistId'));
  }
  
  static Future<void> updateSong(String songId, {String? title, String? artist}) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (artist != null) body['artist'] = artist;
    await http.patch(
      Uri.parse('$baseUrl/api/songs/$songId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
  }
  
  static Future<void> deleteSong(String songId) async {
    await http.delete(Uri.parse('$baseUrl/api/songs/$songId'));
  }

  static String getStreamUrl(String songId) {
    return '$baseUrl/api/stream/$songId';
  }

  // Like/Dislike
  static Future<void> likeSong(String songId) async {
    await http.post(Uri.parse('$baseUrl/api/songs/$songId/like'));
  }

  static Future<void> dislikeSong(String songId) async {
    await http.post(Uri.parse('$baseUrl/api/songs/$songId/dislike'));
  }

  static Future<bool?> getLikeStatus(String songId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/songs/$songId/like-status'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['liked']; // true, false, or null
    }
    return null;
  }

  static Future<List<Song>> getRecommendations({int limit = 10}) async {
    final response = await http.get(Uri.parse('$baseUrl/api/recommendations?limit=$limit'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> recs = data['recommendations'] ?? [];
      return recs.map((j) => Song.fromJson(j)).toList();
    }
    return [];
  }
}
