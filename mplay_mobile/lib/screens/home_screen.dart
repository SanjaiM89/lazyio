import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'album_detail_screen.dart';

/// Phone home matching the Library mockup: header, pill search with
/// source segmented control + Hi-Res chip, spotlight card, tracklist
/// with albums grid. Mini-player and bottom tab bar come from MainScreen.
class HomeScreen extends StatefulWidget {
  final Function(int, [String?]) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _data;
  List<Album> _albums = [];
  bool _loading = true;
  int _sourceTab = 0;
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

  void _shufflePlay(List<Song> tracks) {
    if (tracks.isEmpty) return;
    final q = List<Song>.of(tracks)..shuffle();
    _play(q.first, q);
  }

  void _play(Song song, List<Song> queue) {
    context.read<MusicProvider>().playSong(song, queue);
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final recent = ((_data?['recently_played'] as List?) ?? []).map((j) => Song.fromJson(j)).toList();
    final aiSongs = (((_data?['ai_playlist'] as Map?)?['songs'] as List?) ?? []).map((j) => Song.fromJson(j)).toList();
    final spotlight = music.currentSong ?? (recent.isNotEmpty ? recent.first : (aiSongs.isNotEmpty ? aiSongs.first : null));
    final tracks = [...recent, ...aiSongs].take(8).toList();

    return Stack(
      children: [
        // Ambient glow bloom
        Positioned(
          top: -40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Nocturne.secondaryContainer.withOpacity(0.2),
              ),
            ),
          ),
        ),
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _searchRow()),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator(color: Nocturne.primary)),
                ),
              )
            else ...[
              if (spotlight != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _spotlight(context, spotlight, music, tracks),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Tracklist & Up Next'),
                      ...tracks.asMap().entries.map((e) {
                        final s = e.value;
                        final active = music.currentSong?.id == s.id;
                        return NocturneTrackRow(
                          song: s,
                          index: e.key,
                          active: active,
                          playing: active && music.isPlaying,
                          onTap: () => _play(s, tracks),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Albums in Library',
                        actionLabel: 'See All',
                        onAction: () => widget.onNavigate(2),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 218,
                        ),
                        itemCount: _albums.take(4).length,
                        itemBuilder: (_, i) {
                          final a = _albums[i];
                          return GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => AlbumDetailScreen(albumId: a.id))),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: Nocturne.glassCard,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Nocturne.surfaceLowest),
                                      clipBehavior: Clip.antiAlias,
                                      width: double.infinity,
                                      child: (a.coverArt != null && a.coverArt!.isNotEmpty)
                                          ? Image.network(a.coverArt!, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.album_rounded, color: Nocturne.outline))
                                          : const Icon(Icons.album_rounded, color: Nocturne.outline),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(a.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                  Text('${a.artist ?? 'Unknown'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Nocturne.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 170)),
          ],
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Library',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.search_rounded, size: 22, color: Nocturne.onSurfaceVariant),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen(initialQuery: '')),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Nocturne.primary),
                  alignment: Alignment.center,
                  child: const Icon(Icons.person_rounded, size: 18, color: Nocturne.onPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
                color: Nocturne.surfaceHigh, borderRadius: BorderRadius.circular(999)),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (q) {
                if (q.trim().isEmpty) return;
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SearchScreen(initialQuery: q.trim())));
              },
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Artists, Songs, Lyrics, and More',
                hintStyle: TextStyle(fontSize: 12, color: Nocturne.onSurfaceVariant),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: Nocturne.onSurfaceVariant),
                suffixIcon: Icon(Icons.mic_none_rounded, size: 18, color: Nocturne.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 210,
                child: SegmentedControl(
                  tabs: const ['Nocturne Music', 'Library'],
                  selected: _sourceTab,
                  onSelect: (i) => setState(() => _sourceTab = i),
                ),
              ),
              const HiResBadge(label: '24-Bit / 96kHz'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _spotlight(BuildContext context, Song song, MusicProvider music, List<Song> tracks) {
    final isCurrent = music.currentSong?.id == song.id && music.isPlaying;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Nocturne.surfaceLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10), color: Nocturne.surfaceLowest),
                  clipBehavior: Clip.antiAlias,
                  child: (song.coverArt != null && song.coverArt!.isNotEmpty)
                      ? Image.network(song.coverArt!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.music_note_rounded, size: 56, color: Nocturne.outline))
                      : const Icon(Icons.music_note_rounded, size: 56, color: Nocturne.outline),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color.fromRGBO(15, 13, 16, 0.55)]),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color.fromRGBO(15, 13, 16, 0.8),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(isCurrent ? 'NOW PLAYING • MASTER DSD' : 'SPOTLIGHT • LOSSLESS',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Nocturne.primary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color.fromRGBO(15, 13, 16, 0.7),
                          borderRadius: BorderRadius.circular(999)),
                      child: const Icon(Icons.graphic_eq_rounded, size: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Nocturne.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    SongBadges(song: song),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite_rounded, size: 20, color: Nocturne.primary),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (isCurrent) {
                      music.pause();
                    } else {
                      _play(song, [song]);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                        color: Nocturne.primaryContainer, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isCurrent ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 18, color: Nocturne.onPrimary),
                        const SizedBox(width: 6),
                        Text(isCurrent ? 'Playing' : 'Play',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: Nocturne.onPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _shufflePlay(tracks),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                        color: Nocturne.surfaceContainer, borderRadius: BorderRadius.circular(999)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shuffle_rounded, size: 17, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Shuffle', style: TextStyle(fontSize: 14, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
