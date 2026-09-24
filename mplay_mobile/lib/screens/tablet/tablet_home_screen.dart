import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api_service.dart';
import '../../models.dart';
import '../../music_provider.dart';
import '../../theme/nocturne.dart';
import '../../widgets/nocturne_widgets.dart';
import '../search_screen.dart';
import '../album_detail_screen.dart';

/// Tablet home matching the Nocturne iPad mockup: floating glass sidebar,
/// pill search + source segmented control, spotlight card, tracklist with
/// albums rail, and a floating transport pill dock.
///
/// Sidebar destinations map to real app surfaces via [onNavigate] (MainScreen
/// tab indexes); Now Playing opens [onOpenPlayer].
class TabletHomeScreen extends StatefulWidget {
  final void Function(int tab) onNavigate;
  final VoidCallback onOpenPlayer;

  const TabletHomeScreen({super.key, required this.onNavigate, required this.onOpenPlayer});

  @override
  State<TabletHomeScreen> createState() => _TabletHomeScreenState();
}

class _TabletHomeScreenState extends State<TabletHomeScreen> {
  Map<String, dynamic>? _data;
  List<Album> _albums = [];
  bool _loading = true;
  bool _scanning = false;
  int _sourceTab = 0; // 0 Nocturne Music, 1 Library
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getHomepage(),
        ApiService.getAlbums(limit: 6),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0] as Map<String, dynamic>;
          _albums = results[1] as List<Album>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      await ApiService.scanTelegramChannel(force: true);
      await _load();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _submitSearch(String q) {
    if (q.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: q.trim())),
    );
  }

  void _play(Song song, List<Song> queue) {
    Provider.of<MusicProvider>(context, listen: false).playSong(song, queue);
  }

  @override
  Widget build(BuildContext context) {
    return _content(context);
  }

  Widget _content(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final recent = ((_data?['recently_played'] as List?) ?? []).map((j) => Song.fromJson(j)).toList();
    final aiSongs = (((_data?['ai_playlist'] as Map?)?['songs'] as List?) ?? []).map((j) => Song.fromJson(j)).toList();
    final spotlight = music.currentSong ?? (recent.isNotEmpty ? recent.first : (aiSongs.isNotEmpty ? aiSongs.first : null));
    final queue = music.playlist.isNotEmpty ? music.playlist : [...recent, ...aiSongs].take(8).toList();

    return Column(
      children: [
        _searchBar(),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Nocturne.primary))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (spotlight != null) _spotlight(context, spotlight, music),
                    const SizedBox(height: 18),
                    _tracklist(context, queue, music),
                    const SizedBox(height: 18),
                    _albumsRail(context),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: Nocturne.glassInput,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: _submitSearch,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Artists, Songs, Lyrics, and More',
                hintStyle: TextStyle(fontSize: 13, color: Nocturne.outline),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: Nocturne.outline),
                suffixIcon: Icon(Icons.mic_none_rounded, size: 16, color: Nocturne.outline),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 220,
          child: SegmentedControl(
            tabs: const ['Nocturne Music', 'Library'],
            selected: _sourceTab,
            onSelect: (i) => setState(() => _sourceTab = i),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _scanning ? null : _scan,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Nocturne.surfaceHigh, borderRadius: BorderRadius.circular(999)),
            child: _scanning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Nocturne.primary))
                : const Icon(Icons.refresh_rounded, size: 16, color: Nocturne.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _spotlight(BuildContext context, Song song, MusicProvider music) {
    final isCurrent = music.currentSong?.id == song.id && music.isPlaying;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Nocturne.surfaceContainer, Nocturne.surfaceHigh, Nocturne.surfaceLow]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Nocturne.border),
      ),
      child: Row(
        children: [
          CoverArt(song: song, size: 120, radius: 16),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Nocturne.primaryContainer.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Nocturne.primaryContainer.withOpacity(0.25))),
                      child: Text(isCurrent ? 'NOW PLAYING • LOSSLESS' : 'SPOTLIGHT • LOSSLESS',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700, color: Nocturne.primary, letterSpacing: 0.6)),
                    ),
                    const SizedBox(width: 8),
                    const Text('24-Bit / 96kHz',
                        style: TextStyle(fontSize: 10, color: Nocturne.outline)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Nocturne.onSurfaceVariant)),
                const SizedBox(height: 4),
                SongBadges(song: song),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _pillButton(isCurrent ? 'Playing' : 'Play',
                        isCurrent ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        filled: true, onTap: () {
                      if (isCurrent) {
                        music.pause();
                      } else {
                        final q = music.playlist.isNotEmpty ? music.playlist : [song];
                        _play(song, q);
                      }
                    }),
                    const SizedBox(width: 8),
                    _pillButton('Shuffle', Icons.shuffle_rounded, onTap: () {
                      final q = List<Song>.of(music.playlist.isNotEmpty ? music.playlist : [song])..shuffle();
                      if (q.isNotEmpty) _play(q.first, q);
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton(String label, IconData icon, {bool filled = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? Nocturne.primaryContainer : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: Nocturne.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: filled ? Colors.black87 : Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: filled ? Colors.black87 : Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _tracklist(BuildContext context, List<Song> queue, MusicProvider music) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
            title: 'Tracklist & Up Next',
            count: '(${queue.length} Tracks)',
            actionLabel: 'Continuous Lossless'),
        ...queue.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final active = music.currentSong?.id == s.id;
          return NocturneTrackRow(
            song: s,
            index: i,
            active: active,
            playing: active && music.isPlaying,
            onTap: () => _play(s, queue),
          );
        }),
      ],
    );
  }

  Widget _albumsRail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Albums in Library', count: '${_albums.length} Albums'),
        SizedBox(
          height: 196,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _albums.length,
            itemBuilder: (_, i) {
              final a = _albums[i];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AlbumDetailScreen(albumId: a.id))),
                child: Container(
                  width: 148,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: Nocturne.glassCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Nocturne.surfaceHighest,
                              border: Border.all(color: Nocturne.border)),
                          clipBehavior: Clip.antiAlias,
                          child: (a.coverArt != null && a.coverArt!.isNotEmpty)
                              ? Image.network(a.coverArt!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.album_rounded, color: Nocturne.outline))
                              : const Icon(Icons.album_rounded, color: Nocturne.outline),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(a.artist ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Nocturne.onSurfaceVariant)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}
