import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../constants.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool? _likeStatus;
  String? _currentSongId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLikeStatus();
    });
  }

  void _loadLikeStatus() {
    final music = Provider.of<MusicProvider>(context, listen: false);
    final song = music.currentSong;
    if (song != null && song.id != _currentSongId) {
      _currentSongId = song.id;
      _fetchLikeStatus(song.id);
    }
  }

  Future<void> _fetchLikeStatus(String songId) async {
    try {
      final status = await ApiService.getLikeStatus(songId);
      if (mounted) setState(() => _likeStatus = status);
    } catch (e) {
      print("Error fetching like status: $e");
    }
  }

  Future<void> _toggleLike() async {
    if (_currentSongId == null) return;
    try {
      if (_likeStatus == true) {
        await ApiService.dislikeSong(_currentSongId!);
        setState(() => _likeStatus = false);
      } else {
        await ApiService.likeSong(_currentSongId!);
        setState(() => _likeStatus = true);
      }
    } catch (e) {
      print("Error toggling like: $e");
    }
  }

  Future<void> _toggleDislike() async {
    if (_currentSongId == null) return;
    try {
      if (_likeStatus == false) {
        await ApiService.likeSong(_currentSongId!);
        setState(() => _likeStatus = true);
      } else {
        await ApiService.dislikeSong(_currentSongId!);
        setState(() => _likeStatus = false);
      }
    } catch (e) {
      print("Error toggling dislike: $e");
    }
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);
    final song = music.currentSong;
    final isTablet = Layout.isTablet(context);

    if (song != null && song.id != _currentSongId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _currentSongId = song.id;
        _fetchLikeStatus(song.id);
      });
    }

    if (song == null) return const Scaffold(body: Center(child: Text("No song selected")));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Blurred background
          if (song.coverArt != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Image.network(
                  song.coverArt!,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.5),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),
          // Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 64 : 32),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Cover Art
                  Expanded(
                    flex: 4,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: song.coverArt != null && song.coverArt!.isNotEmpty
                              ? Image.network(song.coverArt!, fit: BoxFit.cover)
                              : Container(color: Colors.white10, child: const Icon(Icons.music_note, size: 80, color: Colors.white24)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title / Artist
                  Text(
                    song.title,
                    style: TextStyle(fontSize: isTablet ? 26 : 22, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    style: TextStyle(fontSize: isTablet ? 18 : 16, color: kPrimaryColor, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  // Progress
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            trackHeight: 4,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: music.position.inSeconds.toDouble().clamp(0, music.duration.inSeconds.toDouble()),
                            max: music.duration.inSeconds.toDouble() > 0 ? music.duration.inSeconds.toDouble() : 1,
                            onChanged: (val) => music.seek(Duration(seconds: val.toInt())),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(music.position), style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500)),
                              Text("-${_formatDuration(music.duration - music.position)}", style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Controls
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(icon: const Icon(Icons.skip_previous_rounded), iconSize: 48, onPressed: () => music.previous(), color: Colors.white),
                        Container(
                          width: isTablet ? 80 : 72,
                          height: isTablet ? 80 : 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 20)],
                          ),
                          child: IconButton(
                            icon: Icon(music.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                            iconSize: isTablet ? 44 : 40,
                            onPressed: () { if (music.isPlaying) music.pause(); else music.resume(); },
                            color: Colors.black,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.skip_next_rounded), iconSize: 48, onPressed: () => music.next(), color: Colors.white),
                      ],
                    ),
                  ),
                  // Bottom actions
                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(_likeStatus == false ? Icons.thumb_down : Icons.thumb_down_outlined, color: _likeStatus == false ? Colors.red : Colors.white54),
                          onPressed: _toggleDislike,
                        ),
                        IconButton(icon: const Icon(Icons.speaker_rounded), onPressed: () {}, color: Colors.white54),
                        IconButton(icon: const Icon(Icons.playlist_play_rounded), onPressed: () {}, color: Colors.white54),
                        IconButton(
                          icon: Icon(_likeStatus == true ? Icons.thumb_up : Icons.thumb_up_outlined, color: _likeStatus == true ? kPrimaryColor : Colors.white54),
                          onPressed: _toggleLike,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
