class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final double duration;
  final String? coverArt;
  final String? thumbnail;
  final String fileName;
  final String? mediaType; // 'audio' or 'video'
  final int? telegramMessageId;
  final bool hasVideo;
  final int? year;
  final String? genre;
  final int playCount;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.coverArt,
    this.thumbnail,
    required this.fileName,
    this.mediaType,
    this.telegramMessageId,
    this.hasVideo = false,
    this.year,
    this.genre,
    this.playCount = 0,
  });

  bool get isVideo => mediaType == 'video' ||
    fileName.toLowerCase().endsWith('.mp4') ||
    fileName.toLowerCase().endsWith('.mkv') ||
    fileName.toLowerCase().endsWith('.webm');

  factory Song.fromJson(Map<String, dynamic> json) {
    // Telegram-backed library: message id is the stream key
    int? tgId;
    final rawTg = json['telegram_message_id'] ?? json['audio_telegram_id'];
    if (rawTg is not null) {
      tgId = rawTg is int ? rawTg : int.tryParse(rawTg.toString());
    }
    // Robust video detection: check flag OR existence of video id
    final bool hasVideo = json['has_video'] == true || json['video_telegram_id'] != null;

    // Determine media type: prefer explicit video if hasVideo is true
    String? mediaType = json['media_type'];
    if (hasVideo && (mediaType == null || mediaType == 'audio')) {
       mediaType = 'video';
    }

    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? '',
      duration: (json['duration'] ?? 0).toDouble(),
      coverArt: json['cover_art'] ?? json['thumbnail'],
      thumbnail: json['thumbnail'],
      fileName: json['file_name'] ?? '',
      mediaType: mediaType,
      telegramMessageId: tgId,
      hasVideo: hasVideo,
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? ''),
      genre: json['genre'],
      playCount: (json['play_count'] ?? 0) is int
          ? json['play_count'] ?? 0
          : int.tryParse((json['play_count'] ?? 0).toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'cover_art': coverArt,
      'thumbnail': thumbnail,
      'file_name': fileName,
      'media_type': mediaType,
      'telegram_message_id': telegramMessageId,
      'has_video': hasVideo,
      'year': year,
      'genre': genre,
      'play_count': playCount,
    };
  }
}


class Artist {
  final String key;
  final String name;
  final String? coverArt;
  final int songCount;
  final int albumCount;
  final int totalPlays;
  final List<Song>? songs;
  final List<ArtistAlbum>? albums;

  Artist({
    required this.key,
    required this.name,
    this.coverArt,
    required this.songCount,
    required this.albumCount,
    required this.totalPlays,
    this.songs,
    this.albums,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    final songsJson = json['songs'] as List?;
    final albumsJson = json['albums'] as List?;
    return Artist(
      key: json['key'] ?? json['name'] ?? '',
      name: json['name'] ?? 'Unknown Artist',
      coverArt: json['cover_art'],
      songCount: json['song_count'] ?? 0,
      albumCount: json['album_count'] ?? 0,
      totalPlays: json['total_plays'] ?? 0,
      songs: songsJson != null && songsJson.isNotEmpty && songsJson.first is Map
          ? songsJson.map((j) => Song.fromJson(j as Map<String, dynamic>)).toList()
          : null,
      albums: albumsJson != null
          ? albumsJson.map((j) => ArtistAlbum.fromJson(j as Map<String, dynamic>)).toList()
          : null,
    );
  }
}


class ArtistAlbum {
  final String? id;
  final String name;
  final int? year;
  final String? coverArt;
  final int songCount;

  ArtistAlbum({this.id, required this.name, this.year, this.coverArt, required this.songCount});

  factory ArtistAlbum.fromJson(Map<String, dynamic> json) {
    return ArtistAlbum(
      id: json['id'],
      name: json['name'] ?? 'Unknown Album',
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? ''),
      coverArt: json['cover_art'],
      songCount: json['song_count'] ?? 0,
    );
  }
}


class Album {
  final String id;
  final String name;
  final String? artist;
  final String? coverArt;
  final int songCount;
  final List<String> songIds;
  final List<Song>? songs;

  Album({
    required this.id,
    required this.name,
    this.artist,
    this.coverArt,
    required this.songCount,
    required this.songIds,
    this.songs,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final songsJson = json['songs'] as List?;
    return Album(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Album',
      artist: json['artist'],
      coverArt: json['cover_art'],
      songCount: (json['song_count'] ?? (songsJson?.length ?? 0)) as int,
      songIds: List<String>.from(json['song_ids'] ?? []),
      songs: songsJson != null && songsJson.isNotEmpty && songsJson.first is Map
          ? songsJson.map((j) => Song.fromJson(j as Map<String, dynamic>)).toList()
          : null,
    );
  }
}

class Playlist {
  final String id;
  final String name;
  final String? description;
  final int songCount;
  final List<String> songIds;
  final String? coverImage;
  final List<Song>? songs; // Full song objects if available

  Playlist({
    required this.id,
    required this.name,
    this.description,
    required this.songCount,
    required this.songIds,
    this.coverImage,
    this.songs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var rawSongs = json['songs'];
    List<Song>? parsedSongs;
    
    if (rawSongs is List) {
      if (rawSongs.isNotEmpty && rawSongs.first is Map) {
        // It's a list of Song objects
        parsedSongs = rawSongs.map((j) => Song.fromJson(j)).toList();
      } 
      // If it's a list of Strings, it's just IDs, so parsedSongs remains null
      // The IDs are captured in songIds below
    }

    return Playlist(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Playlist',
      description: json['description'],
      songCount: (json['song_ids'] as List?)?.length ?? (json['songs'] as List?)?.length ?? 0,
      songIds: json['song_ids'] != null 
          ? List<String>.from(json['song_ids'])
          : (rawSongs is List && rawSongs.isNotEmpty && rawSongs.first is String)
              ? List<String>.from(rawSongs)
              : [],
      coverImage: json['cover_image'],
      songs: parsedSongs,
    );
  }
}
