import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_provider.dart';
import '../screens/unified_player_screen.dart';
import '../providers/video_provider.dart';
import '../constants.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);
    final song = music.currentSong;

    if (song == null) return const SizedBox.shrink();

    final progress = music.duration.inSeconds > 0
        ? music.position.inSeconds / music.duration.inSeconds
        : 0.0;
    final isTablet = Layout.isTablet(context);

    return GestureDetector(
      onTap: () {
        Provider.of<VideoProvider>(context, listen: false).close();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UnifiedPlayerScreen(song: song, startWithVideo: false),
            fullscreenDialog: true,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(isTablet ? 12 : 16, 0, isTablet ? 12 : 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Art
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: song.coverArt != null
                                ? Image.network(song.coverArt!, width: 48, height: 48, fit: BoxFit.cover)
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: kSurfaceColor,
                                    child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 30,
                              ),
                              onPressed: () {
                                if (music.isPlaying) music.pause(); else music.resume();
                              },
                              color: Colors.white,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, size: 26),
                              onPressed: () => music.next(),
                              color: Colors.white70,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  Container(
                    height: 2.5,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
                      minHeight: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
