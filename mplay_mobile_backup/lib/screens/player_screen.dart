import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_provider.dart';
import '../constants.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);
    final song = music.currentSong;

    if (song == null) return const Scaffold(body: Center(child: Text("No song selected")));

    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background visual
          if (song.coverArt != null)
            Positioned.fill(
              child: Image.network(
                song.coverArt!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.8),
                colorBlendMode: BlendMode.darken,
              ),
            ),
            
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Spacer(),
                  // Cover Art
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                           BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: song.coverArt != null
                            ? Image.network(song.coverArt!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.white10,
                                child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Title / Artist
                  Column(
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.artist,
                        style: const TextStyle(fontSize: 16, color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Seeker
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 4,
                      activeTrackColor: kPrimaryColor,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: music.position.inSeconds.toDouble().clamp(0, music.duration.inSeconds.toDouble()),
                      max: music.duration.inSeconds.toDouble() > 0 ? music.duration.inSeconds.toDouble() : 1,
                      onChanged: (val) {
                        music.seek(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(music.position), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        Text(_formatDuration(music.duration), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, size: 36),
                        onPressed: () => music.previous(),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 24),
                      Container(
                        width: 64, 
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [kPrimaryColor, kSecondaryColor]),
                        ),
                        child: IconButton(
                          icon: Icon(music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                          onPressed: () {
                            if (music.isPlaying) music.pause(); else music.resume();
                          },
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 36),
                        onPressed: () => music.next(),
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '${min}:${sec.toString().padStart(2, '0')}';
  }
}
