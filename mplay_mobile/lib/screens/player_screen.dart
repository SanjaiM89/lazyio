import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';

/// Phone fullscreen Now Playing matching the crimson mockup: ambient glow,
/// glass header, hero artwork, badges, Play/Shuffle pills, scrubber,
/// transport row, quick actions and the Playing Next queue.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool? _liked;
  bool _shuffle = false;
  bool _repeat = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLike());
  }

  Future<void> _loadLike() async {
    final song = context.read<MusicProvider>().currentSong;
    if (song == null || !mounted) return;
    try {
      final s = await ApiService.getLikeStatus(song.id);
      if (mounted) setState(() => _liked = s);
    } catch (_) {}
  }

  Future<void> _toggleLike(Song song) async {
    setState(() => _liked = !(_liked ?? false));
    try {
      if (_liked == true) {
        await ApiService.likeSong(song.id);
      } else {
        await ApiService.dislikeSong(song.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final song = music.currentSong;
    if (song == null) {
      return const Scaffold(
        backgroundColor: Nocturne.crimsonBg,
        body: Center(child: Text('Nothing playing', style: TextStyle(color: Nocturne.outline))),
      );
    }
    final queue = music.playlist.where((s) => s.id != song.id).toList();

    return Scaffold(
      backgroundColor: Nocturne.crimsonBg,
      body: Stack(
        children: [
          // Ambient radial glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.5, 0.28),
                  radius: 0.75,
                  colors: [
                    const Color(0xFF87182E).withOpacity(0.55),
                    const Color(0xFF370C16).withOpacity(0.25),
                    Nocturne.crimsonBg.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      _heroArt(song),
                      const SizedBox(height: 14),
                      _titleBlock(song),
                      const SizedBox(height: 10),
                      _metaBadges(song),
                      const SizedBox(height: 14),
                      _actionPills(context, music, song),
                      const SizedBox(height: 14),
                      NocturneSeekBar(
                        position: music.position,
                        duration: music.duration.inMilliseconds > 0
                            ? music.duration
                            : Duration(seconds: song.duration.round()),
                        onSeek: music.seek,
                        activeColor: Nocturne.peach,
                      ),
                      const SizedBox(height: 8),
                      _transport(context, music),
                      const SizedBox(height: 14),
                      _quickActions(),
                      const SizedBox(height: 18),
                      _queueSection(context, music, queue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(36, 12, 18, 0.65),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26, color: Color(0xFFD6C9C9)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('NOW PLAYING',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0, color: Nocturne.peach)),
              SizedBox(height: 1),
              Text('Top Hits India • 2024', style: TextStyle(fontSize: 12, color: Color(0xFFA89E9E))),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.cast_rounded, size: 19, color: Color(0xFFD6C9C9)),
                  onPressed: () {}),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_horiz_rounded, size: 22, color: Color(0xFFD6C9C9)),
                  onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroArt(Song song) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 50, offset: Offset(0, 20)),
            BoxShadow(color: Color(0x4D751B32)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              (song.coverArt != null && song.coverArt!.isNotEmpty)
                  ? Image.network(song.coverArt!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Nocturne.crimsonDeep,
                          child: Icon(Icons.music_note_rounded, size: 64, color: Nocturne.outline)))
                  : const ColoredBox(
                      color: Nocturne.crimsonDeep,
                      child: Icon(Icons.music_note_rounded, size: 64, color: Nocturne.outline)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54, Colors.transparent]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBlock(Song song) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Nocturne.peach.withOpacity(0.2)),
                    child: const Icon(Icons.check_rounded, size: 11, color: Nocturne.peach),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: Nocturne.peach)),
              const SizedBox(height: 4),
              SongBadges(song: song),
            ],
          ),
        ),
        IconButton(
          icon: Icon(_liked == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 26, color: _liked == true ? const Color(0xFFF0607E) : const Color(0xFF8E837F)),
          onPressed: () => _toggleLike(song),
        ),
      ],
    );
  }

  Widget _metaBadges(Song song) {
    Widget chip(String label, {bool accent = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent ? Nocturne.peach.withOpacity(0.1) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: accent ? Nocturne.peach.withOpacity(0.25) : Colors.white.withOpacity(0.1)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: accent ? Nocturne.peach : const Color(0xFFD6C9C9))),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip(song.genre?.isNotEmpty == true ? song.genre! : 'Indie'),
        chip(song.year != null ? '${song.year}' : '2024'),
        chip('Lossless', accent: true),
      ],
    );
  }

  Widget _actionPills(BuildContext context, MusicProvider music, Song song) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => music.isPlaying ? music.pause() : music.resume(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Nocturne.peach,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(color: Nocturne.peach.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18, color: const Color(0xFF1A080D)),
                  const SizedBox(width: 6),
                  Text(music.isPlaying ? 'Playing' : 'Play',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A080D))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () {
              final q = List<Song>.of(music.playlist)..shuffle();
              if (q.isNotEmpty) music.playSong(q.first, q);
              setState(() => _shuffle = !_shuffle);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shuffle_rounded, size: 17, color: _shuffle ? Nocturne.peach : Colors.white),
                  const SizedBox(width: 6),
                  const Text('Shuffle',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _transport(BuildContext context, MusicProvider music) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
            icon: Icon(Icons.shuffle_rounded, size: 21,
                color: _shuffle ? Nocturne.peach : const Color(0xFF8E837F)),
            onPressed: () => setState(() => _shuffle = !_shuffle)),
        IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 30, color: Color(0xFFD6C9C9)),
            onPressed: music.previous),
        GestureDetector(
          onTap: () => music.isPlaying ? music.pause() : music.resume(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Nocturne.peach, Nocturne.coral], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(color: const Color(0xFFB41E3C).withOpacity(0.45), blurRadius: 40, offset: const Offset(0, 12)),
              ],
            ),
            child: Icon(music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 30, color: const Color(0xFF1A080D)),
          ),
        ),
        IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 30, color: Color(0xFFD6C9C9)),
            onPressed: music.next),
        IconButton(
            icon: Icon(Icons.repeat_rounded, size: 21,
                color: _repeat ? Nocturne.peach : const Color(0xFF8E837F)),
            onPressed: () => setState(() => _repeat = !_repeat)),
      ],
    );
  }

  Widget _quickActions() {
    Widget item(IconData icon, String label, {bool highlight = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: highlight ? Nocturne.peach : const Color(0xFF8E837F)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                    color: highlight ? Colors.white : const Color(0xFF8E837F))),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          item(Icons.share_outlined, 'Share'),
          item(Icons.queue_music_rounded, 'Queue', highlight: true),
          item(Icons.speaker_rounded, 'AirPlay'),
        ],
      ),
    );
  }

  Widget _queueSection(BuildContext context, MusicProvider music, List<Song> queue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Playing Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('From "South Indie Spotlight"',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8E837F))),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: const Text('Autoplay',
                  style: TextStyle(fontSize: 12, color: Color(0xFFD6C9C9))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (queue.isEmpty)
          const Text('Play more to fill the queue.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E837F)))
        else
          ...queue.take(8).toList().asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NocturneTrackRow(
                song: s,
                index: i,
                onTap: () => music.playSong(s, music.playlist),
              ),
            );
          }),
      ],
    );
  }
}
