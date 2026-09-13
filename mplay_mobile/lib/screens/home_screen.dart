import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../constants.dart';
import '../providers/video_provider.dart';
import 'settings_screen.dart';
import 'playlist_detail_screen.dart';
import 'album_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int, [String?]) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _data;
  List<Playlist> _appPlaylists = [];
  List<Album> _albums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getHomepage(),
        ApiService.getAppPlaylists(),
        ApiService.getAlbums(limit: 10),
      ]);

      if (mounted) {
        setState(() {
          _data = results[0] as Map<String, dynamic>;
          _appPlaylists = results[1] as List<Playlist>;
          _albums = results[2] as List<Album>;
          _loading = false;
        });
      }
    } catch (e) {
      print("Error loading home data: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }

    final recentJson = _data?['recently_played'] as List? ?? [];
    final recentSongs = recentJson.map((j) => Song.fromJson(j)).toList();

    final aiPlaylistJson = _data?['ai_playlist'] as Map?;
    final aiPlaylistName = aiPlaylistJson?['name'] ?? 'AI Mix';
    final aiSongsJson = aiPlaylistJson?['songs'] as List? ?? [];
    final aiSongs = aiSongsJson.map((j) => Song.fromJson(j)).toList();

    final isTablet = Layout.isTablet(context);
    final pad = Layout.horizontalPadding(context);
    final topPad = Layout.topPadding(context);

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, topPad, pad, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Listen Now',
                      style: TextStyle(
                        fontSize: isTablet ? 38 : 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your personal music space',
                      style: TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.settings_rounded, color: Colors.white54, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Recently Played
        if (recentSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 32, pad, 16),
              child: const Text(
                'Recently Played',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: isTablet ? 260 : 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: recentSongs.length,
                itemBuilder: (context, index) {
                  final song = recentSongs[index];
                  final cardWidth = isTablet ? 180.0 : 150.0;
                  return GestureDetector(
                    onTap: () {
                      if (song.isVideo) {
                        Provider.of<MusicProvider>(context, listen: false).stop();
                        Provider.of<VideoProvider>(context, listen: false).playVideo(song);
                      } else {
                        Provider.of<VideoProvider>(context, listen: false).close();
                        Provider.of<MusicProvider>(context, listen: false).playSong(song, recentSongs);
                      }
                    },
                    child: Container(
                      width: cardWidth,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: song.coverArt != null
                                    ? Image.network(song.coverArt!, fit: BoxFit.cover, width: cardWidth, height: cardWidth)
                                    : Container(
                                        color: kSurfaceColor,
                                        width: cardWidth,
                                        height: cardWidth,
                                        child: const Icon(Icons.music_note, size: 48, color: Colors.white24),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // AI Playlist
        if (aiSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 32, pad, 16),
              child: Row(
                children: [
                  Text(aiPlaylistName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPrimaryColor, Color(0xFFFF6B6B)]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text("AI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: pad),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: aiSongs.take(5).map((song) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.coverArt != null && song.coverArt!.isNotEmpty
                        ? Image.network(song.coverArt!, width: 44, height: 44, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 44, height: 44, color: Colors.white10,
                              child: const Icon(Icons.music_note, size: 20, color: Colors.white38),
                            ))
                        : Container(
                            width: 44, height: 44, color: Colors.white10,
                            child: const Icon(Icons.music_note, size: 20, color: Colors.white38),
                          ),
                  ),
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: Text(
                    "${(song.duration / 60).floor()}:${(song.duration % 60).toInt().toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  onTap: () => Provider.of<MusicProvider>(context, listen: false).playSong(song, aiSongs),
                )).toList(),
              ),
            ),
          ),
        ],

        // App Playlists
        if (_appPlaylists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 32, pad, 16),
              child: Row(
                children: [
                  const Text('Curated Playlists', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ApiService.generateAppPlaylist().then((_) => _loadData()),
                    child: const Text('Generate New', style: TextStyle(color: kPrimaryColor)),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: isTablet ? 230 : 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: _appPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = _appPlaylists[index];
                  final cardWidth = isTablet ? 170.0 : 140.0;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: playlist)),
                    ),
                    child: Container(
                      width: cardWidth,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: playlist.coverImage != null
                                    ? DecorationImage(image: NetworkImage(playlist.coverImage!), fit: BoxFit.cover)
                                    : null,
                                color: kSurfaceColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: playlist.coverImage == null
                                  ? const Center(child: Icon(Icons.queue_music, size: 40, color: Colors.white24))
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('${playlist.songCount} Songs',
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // Albums
        if (_albums.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 32, pad, 16),
              child: const Text('Albums', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: isTablet ? 230 : 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: _albums.length,
                itemBuilder: (context, index) {
                  final album = _albums[index];
                  final cardWidth = isTablet ? 170.0 : 140.0;
                  return GestureDetector(
                    onTap: () => widget.onNavigate(2),
                    child: Container(
                      width: cardWidth,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: kSurfaceColor,
                              ),
                              child: album.coverArt != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(album.coverArt!, fit: BoxFit.cover),
                                    )
                                  : const Center(child: Icon(Icons.album, size: 40, color: Colors.white24)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('${album.songCount} Songs',
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // Quick Actions
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 32, pad, 16),
            child: const Text('Quick Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 100),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isTablet ? 4 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: isTablet ? 2.5 : 1.8,
              children: [
                _buildQuickAction('Albums', Icons.album_rounded, const Color(0xFFFF3B30), () => widget.onNavigate(2)),
                _buildQuickAction('Artists', Icons.person_rounded, const Color(0xFFFF9500), () => widget.onNavigate(3)),
                _buildQuickAction('Upload', Icons.upload_file_rounded, const Color(0xFF007AFF), () => widget.onNavigate(4)),
                _buildQuickAction('Library', Icons.library_music_rounded, const Color(0xFFAF52DE), () => widget.onNavigate(1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
