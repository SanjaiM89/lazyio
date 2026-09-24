import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api_service.dart';
import '../../models.dart';
import '../../music_provider.dart';
import '../../theme/nocturne.dart';
import '../../widgets/nocturne_widgets.dart';
import '../../widgets/lyrics_view.dart';

/// Tablet fullscreen player matching the immersive mockup: left vinyl
/// stage (ambient blooms, format ribbons, artwork, badges, scrubber,
/// full transport + volume) and right frosted panel with
/// Playing Next / Lyrics / Stream Info tabs, queue, autoplay and DAC card.
class TabletPlayerScreen extends StatefulWidget {
  const TabletPlayerScreen({super.key});

  @override
  State<TabletPlayerScreen> createState() => _TabletPlayerScreenState();
}

class _TabletPlayerScreenState extends State<TabletPlayerScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0; // 0 queue, 1 lyrics, 2 specs
  bool _loved = false;
  bool _shuffle = false;
  bool _repeatOne = false;
  bool _autoplay = true;
  List<Song> _related = [];
  late final AnimationController _disc;

  @override
  void initState() {
    super.initState();
    _disc = AnimationController(vsync: this, duration: const Duration(seconds: 22))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRelated());
  }

  @override
  void dispose() {
    _disc.dispose();
    super.dispose();
  }

  Future<void> _loadRelated() async {
    final song = context.read<MusicProvider>().currentSong;
    if (song == null) return;
    try {
      final rel = await ApiService.getSimilarSongs(song.id, limit: 8);
      if (mounted) setState(() => _related = rel);
    } catch (_) {}
  }

  Future<void> _toggleLike(Song song) async {
    setState(() => _loved = !_loved);
    try {
      if (_loved) {
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
        backgroundColor: Nocturne.background,
        body: Center(child: Text('Nothing playing', style: TextStyle(color: Nocturne.outline))),
      );
    }
    if (music.isPlaying && !_disc.isAnimating) {
      _disc.repeat();
    } else if (!music.isPlaying && _disc.isAnimating) {
      _disc.stop();
    }

    return Scaffold(
      backgroundColor: Nocturne.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 860;
                  if (!wide) {
                    return ListView(
                      children: [
                        _stage(context, music, song),
                        const SizedBox(height: 14),
                        SizedBox(height: 520, child: _drawer(context, music, song)),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _stage(context, music, song)),
                      const SizedBox(width: 16),
                      SizedBox(width: 400, child: _drawer(context, music, song)),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(15, 13, 16, 0.6),
        border: Border(bottom: BorderSide(color: Nocturne.border)),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26, color: Nocturne.onSurfaceVariant),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(),
                    SizedBox(width: 6),
                    Text('LIVING ROOM HI-FI',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Colors.white)),
                  ],
                ),
                SizedBox(height: 1),
                Text('Bit-Perfect ALAC • 24-Bit / 96kHz',
                    style: TextStyle(fontSize: 11, color: Nocturne.onSurfaceVariant)),
              ],
            ),
          ),
          const Icon(Icons.airplay_rounded, size: 20, color: Nocturne.outline),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => setState(() => _tab = 1),
            child: Icon(Icons.lyrics_outlined, size: 20,
                color: _tab == 1 ? Nocturne.primary : Nocturne.outline),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.fullscreen_exit_rounded, size: 20, color: Nocturne.outline),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Nocturne.primary),
            alignment: Alignment.center,
            child: const Icon(Icons.person_rounded, size: 18, color: Nocturne.onPrimary),
          ),
        ],
      ),
    );
  }

  Widget _stage(BuildContext context, MusicProvider music, Song song) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(15, 13, 16, 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Nocturne.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Nocturne.surfaceHigh,
                        borderRadius: BorderRadius.circular(999)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(),
                        SizedBox(width: 6),
                        Text('33 RPM • PURE MICROGROOVE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Nocturne.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(_loved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 22, color: _loved ? Nocturne.primary : Nocturne.onSurfaceVariant),
                      onPressed: () => _toggleLike(song)),
                  IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.spatial_audio_off_rounded, size: 21, color: Nocturne.onSurfaceVariant),
                      onPressed: () {}),
                  IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.more_vert_rounded, size: 21, color: Nocturne.onSurfaceVariant),
                      onPressed: () {}),
                ],
              ),
            ],
          ),
          Flexible(
            child: Center(
              child: LayoutBuilder(builder: (context, c) {
                final size = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight).clamp(200.0, 380.0);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grooved vinyl
                    RotationTransition(
                      turns: _disc,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0A0A0C),
                          border: Border.all(color: Colors.white.withOpacity(0.09)),
                          boxShadow: [
                            BoxShadow(color: Nocturne.secondaryContainer.withOpacity(0.35), blurRadius: 60, spreadRadius: 8),
                          ],
                        ),
                        child: CustomPaint(painter: _GroovesPainter()),
                      ),
                    ),
                    // Center label with cover + metadata
                    Container(
                      width: size * 0.42,
                      height: size * 0.42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Nocturne.primaryContainer,
                        border: Border.all(color: Nocturne.primaryContainer.withOpacity(0.6), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (song.coverArt != null && song.coverArt!.isNotEmpty)
                            Image.network(song.coverArt!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                          Container(color: Colors.black.withOpacity(0.45)),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text((song.album.isNotEmpty ? song.album : 'LAZYIO').toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: Nocturne.primary)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                              Text(song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 9, color: Nocturne.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Nocturne.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                    child: const Text('MASTER QUALITY AUTHENTICATED',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Nocturne.primary)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Nocturne.surfaceHigh, borderRadius: BorderRadius.circular(999)),
                    child: const Text('24-BIT / 96KHZ ALAC',
                        style: TextStyle(fontSize: 10, color: Nocturne.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: Nocturne.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, size: 16, color: Nocturne.primary),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                  '${song.album.isNotEmpty ? song.album : 'Single'}${song.year != null ? ' • ${song.year}' : ''} • Lossless',
                  style: const TextStyle(fontSize: 12, color: Nocturne.outline)),
              const SizedBox(height: 4),
              SongBadges(song: song),
              const SizedBox(height: 10),
              NocturneSeekBar(
                position: music.position,
                duration: music.duration.inMilliseconds > 0
                    ? music.duration
                    : Duration(seconds: song.duration.round()),
                onSeek: music.seek,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _tbtn(Icons.shuffle_rounded, _shuffle, () => setState(() => _shuffle = !_shuffle)),
                      _tbtn(Icons.repeat_one_rounded, _repeatOne, () => setState(() => _repeatOne = !_repeatOne)),
                    ],
                  ),
                  Row(
                    children: [
                      _tbtn(Icons.skip_previous_rounded, false, music.previous, size: 30),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => music.isPlaying ? music.pause() : music.resume(),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Nocturne.primaryContainer,
                            boxShadow: [
                              BoxShadow(color: Nocturne.primaryContainer.withOpacity(0.45), blurRadius: 24),
                            ],
                          ),
                          child: Icon(music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 34, color: Nocturne.onPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _tbtn(Icons.skip_next_rounded, false, music.next, size: 30),
                    ],
                  ),
                  SizedBox(
                    width: 150,
                    child: Row(
                      children: [
                        const Icon(Icons.volume_down_rounded, size: 17, color: Nocturne.outline),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: Nocturne.onSurfaceVariant,
                              inactiveTrackColor: Colors.white.withOpacity(0.12),
                              thumbColor: Nocturne.onSurfaceVariant,
                            ),
                            child: Slider(value: music.volume, onChanged: music.setVolume),
                          ),
                        ),
                        const Icon(Icons.volume_up_rounded, size: 17, color: Nocturne.outline),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tbtn(IconData icon, bool active, VoidCallback onTap, {double size = 20}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: size, color: active ? Nocturne.primary : Nocturne.onSurfaceVariant),
      onPressed: onTap,
    );
  }

  Widget _drawer(BuildContext context, MusicProvider music, Song song) {
    final queue = music.playlist;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(29, 27, 30, 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Nocturne.border),
      ),
      child: Column(
        children: [
          SegmentedControl(
            tabs: ['Playing Next (${queue.length})', 'Lyrics', 'Stream Info'],
            selected: _tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _tab == 0
                ? _queueTab(context, music, queue)
                : _tab == 1
                    ? LyricsView(song: song, position: music.position, onSeek: music.seek)
                    : _specsTab(song),
          ),
          const SizedBox(height: 10),
          _autoplayFooter(),
        ],
      ),
    );
  }

  Widget _queueTab(BuildContext context, MusicProvider music, List<Song> queue) {
    final upcoming = queue.isEmpty
        ? _related
        : queue.where((s) => s.id != music.currentSong?.id).toList();
    if (upcoming.isEmpty) {
      return const Center(
          child: Text('Play more to get recommendations.',
              style: TextStyle(fontSize: 12, color: Nocturne.outline)));
    }
    return ListView.builder(
      itemCount: upcoming.length,
      itemBuilder: (_, i) {
        final s = upcoming[i];
        final active = music.currentSong?.id == s.id;
        return NocturneTrackRow(
          song: s,
          index: i,
          active: active,
          playing: active && music.isPlaying,
          onTap: () => music.playSong(s, queue.isEmpty ? upcoming : queue),
        );
      },
    );
  }

  Widget _specsTab(Song song) {
    final rows = <List<String>>[
      ['Format', 'ALAC • Bit-Perfect'],
      ['Sample rate', '24-Bit / 96kHz'],
      ['Tempo', song.bpm != null && song.bpm! > 0 ? '${song.bpm!.round()} BPM' : '—'],
      ['Mood energy', song.energy != null ? '${(song.energy! * 100).round()}%' : '—'],
      ['Language', song.language ?? '—'],
      ['Year', '${song.year ?? '—'}'],
      ['Plays', '${song.playCount}'],
    ];
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(color: Nocturne.border, height: 1),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(rows[i][0], style: const TextStyle(fontSize: 13, color: Nocturne.onSurfaceVariant)),
            Text(rows[i][1],
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _autoplayFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: Nocturne.surfaceHigh.withOpacity(0.6), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.all_inclusive_rounded, size: 20, color: Nocturne.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AutoPlay Similar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                Text('Continuous smart stream',
                    style: TextStyle(fontSize: 11, color: Nocturne.onSurfaceVariant)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _autoplay = !_autoplay),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              alignment: _autoplay ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: _autoplay ? Nocturne.primaryContainer : Nocturne.surfaceHighest,
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c.drive(Tween(begin: 1.0, end: 0.35)),
      child: Container(
          width: 6, height: 6,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Nocturne.primaryContainer)),
    );
  }
}

class _GroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    for (double r = size.width * 0.24; r < size.width * 0.49; r += 5) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
