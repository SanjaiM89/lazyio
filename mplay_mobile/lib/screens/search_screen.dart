import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../constants.dart';
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
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Search failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);
    final pad = Layout.horizontalPadding(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: false,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: Colors.white),
          onSubmitted: _performSearch,
          decoration: const InputDecoration(
            hintText: 'Search songs, albums, artists...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_controller.text),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : (_songs.isEmpty && _albums.isEmpty && _artists.isEmpty)
              ? Center(
                  child: Text(
                    'No results for "${_controller.text}"',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
                  children: [
                    // Artists Section
                    if (_artists.isNotEmpty) ...[
                      const Text(
                        'Artists',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
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
                                width: 90,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: kSurfaceColor,
                                        image: artist.coverArt != null
                                            ? DecorationImage(
                                                image: NetworkImage(artist.coverArt!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: artist.coverArt == null
                                          ? const Icon(Icons.person, color: Colors.white38, size: 36)
                                          : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      artist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Albums Section
                    if (_albums.isNotEmpty) ...[
                      const Text(
                        'Albums',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 170,
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
                                width: 120,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: kSurfaceColor,
                                        image: album.coverArt != null
                                            ? DecorationImage(
                                                image: NetworkImage(album.coverArt!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: album.coverArt == null
                                          ? const Center(child: Icon(Icons.album, color: Colors.white24, size: 40))
                                          : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      album.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${album.songCount} songs',
                                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Songs Section
                    if (_songs.isNotEmpty) ...[
                      const Text(
                        'Songs',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _songs.length,
                        itemBuilder: (context, i) {
                          final song = _songs[i];
                          return SongTile(
                            song: song,
                            isPlaying: music.currentSong?.id == song.id,
                            onTap: () {
                              if (song.isVideo) {
                                Provider.of<MusicProvider>(context, listen: false).stop();
                                Provider.of<VideoProvider>(context, listen: false).playVideo(song);
                              } else {
                                Provider.of<VideoProvider>(context, listen: false).close();
                                music.playSong(song, _songs);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
    );
  }
}
