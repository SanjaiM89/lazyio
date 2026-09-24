import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';
import '../widgets/song_tile.dart';
import '../providers/video_provider.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, required this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _controller;
  List<Song> _songs = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  String? _languageFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _performSearch(widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService.searchLibrary(query.trim());
      final List<dynamic> songsJson = data['songs'] ?? [];
      final List<dynamic> albumsJson = data['albums'] ?? [];
      final List<dynamic> artistsJson = data['artists'] ?? [];

      if (mounted) {
        setState(() {
          _songs = songsJson.map((j) => Song.fromJson(j)).toList();
          _albums = albumsJson.map((j) => Album.fromJson(j)).toList();
          _artists = artistsJson.map((j) => Artist.fromJson(j)).toList();
          _languageFilter = data['language_filter'];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Search failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _play(Song song, List<Song> queue) {
    if (song.isVideo) {
      Provider.of<MusicProvider>(context, listen: false).stop();
      Provider.of<VideoProvider>(context, listen: false).playVideo(song);
    } else {
      Provider.of<VideoProvider>(context, listen: false).close();
      Provider.of<MusicProvider>(context, listen: false).playSong(song, queue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);

    return Scaffold(
      backgroundColor: Nocturne.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          decoration: BoxDecoration(
              color: Nocturne.surfaceHigh, borderRadius: BorderRadius.circular(999)),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onSubmitted: _performSearch,
            decoration: const InputDecoration(
              hintText: 'Search songs, albums, artists...',
              hintStyle: TextStyle(color: Nocturne.onSurfaceVariant, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search_rounded, color: Nocturne.onSurfaceVariant, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Nocturne.primary),
            onPressed: () => _performSearch(_controller.text),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Nocturne.primary))
          : (_songs.isEmpty && _albums.isEmpty && _artists.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_rounded, size: 44, color: Nocturne.outline),
                        const SizedBox(height: 12),
                        Text(
                          _languageFilter != null
                              ? 'No labeled $_languageFilter songs yet'
                              : 'No results for "${_controller.text}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _languageFilter != null
                              ? 'Label a few tracks or run audio analysis and they will appear here.'
                              : 'Check spelling or try an artist name.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Nocturne.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    if (_languageFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Nocturne.primaryContainer,
                                  borderRadius: BorderRadius.circular(999)),
                              child: Text('$_languageFilter only',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Nocturne.onPrimary)),
                            ),
                          ],
                        ),
                      ),
                    if (_artists.isNotEmpty) ...[
                      const SectionHeader(title: 'Artists'),
                      SizedBox(
                        height: 108,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _artists.length,
                          itemBuilder: (context, i) {
                            final artist = _artists[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArtistDetailScreen(artistName: artist.name),
                                ),
                              ),
                              child: Container(
                                width: 84,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Nocturne.surfaceHighest,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: artist.coverArt != null
                                          ? Image.network(artist.coverArt!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.person_rounded,
                                                  color: Nocturne.outline))
                                          : const Icon(Icons.person_rounded,
                                              color: Nocturne.outline),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      artist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_albums.isNotEmpty) ...[
                      const SectionHeader(title: 'Albums'),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _albums.length,
                          itemBuilder: (context, i) {
                            final album = _albums[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AlbumDetailScreen(albumId: album.id),
                                ),
                              ),
                              child: Container(
                                width: 112,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Nocturne.surfaceHighest,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: album.coverArt != null
                                          ? Image.network(album.coverArt!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.album_rounded,
                                                  color: Nocturne.outline))
                                          : const Icon(Icons.album_rounded,
                                              color: Nocturne.outline),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      album.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                    ),
                                    Text(
                                      '${album.songCount} songs',
                                      style: const TextStyle(
                                          fontSize: 11, color: Nocturne.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_songs.isNotEmpty) ...[
                      const SectionHeader(title: 'Songs'),
                      ..._songs.map((song) => SongTile(
                            song: song,
                            isPlaying: music.currentSong?.id == song.id,
                            onTap: () => _play(song, _songs),
                          )),
                    ],
                  ],
                ),
    );
  }
}
