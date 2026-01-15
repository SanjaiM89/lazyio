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

  static String getStreamUrl(String songId) {
    return '$baseUrl/api/stream/$songId';
  }
}
