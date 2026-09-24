import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_provider.dart';
import '../theme/nocturne.dart';
import 'nocturne_widgets.dart';
import '../screens/tablet/tablet_player_screen.dart';
import '../screens/player_screen.dart';
import '../constants.dart';

/// Floating mini-player docked above the bottom nav (mockup 4):
/// cover, title + HI-RES badge, artist, play / next / queue buttons,
/// hairline progress. Tap opens the fullscreen player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  void _openPlayer(BuildContext context) {
    final tablet = Layout.isTablet(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            tablet ? const TabletPlayerScreen() : const PlayerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);
    final song = music.currentSong;

    if (song == null) return const SizedBox.shrink();

    final progress = music.duration.inMilliseconds > 0
        ? (music.position.inMilliseconds / music.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => _openPlayer(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(44, 41, 44, 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Nocturne.surfaceHighest.withOpacity(0.5)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    CoverArt(song: song, size: 44, radius: 8),
                    const SizedBox(width: 10),
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
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                    color: Nocturne.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(3)),
                                child: const Text('HI-RES 96kHz',
                                    style: TextStyle(
                                        fontSize: 8, fontWeight: FontWeight.w800, color: Nocturne.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Nocturne.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => music.isPlaying ? music.pause() : music.resume(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Nocturne.primaryContainer),
                        child: Icon(
                            music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 20,
                            color: Nocturne.onPrimary),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.skip_next_rounded, size: 20, color: Nocturne.onSurfaceVariant),
                      onPressed: music.next,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.queue_music_rounded, size: 19, color: Nocturne.onSurfaceVariant),
                      onPressed: () => _openPlayer(context),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 2,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: Nocturne.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
