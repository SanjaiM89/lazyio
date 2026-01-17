import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../music_provider.dart';
import '../providers/video_provider.dart';
import '../constants.dart';
import '../api_service.dart';
import '../models.dart';

/// Unified Player Screen - YouTube Music Style
/// Features Song/Video toggle, unified controls, and tabs
class UnifiedPlayerScreen extends StatefulWidget {
  final Song song;
  final bool startWithVideo;

  const UnifiedPlayerScreen({
    super.key,
    required this.song,
    this.startWithVideo = false,
  });

  @override
  State<UnifiedPlayerScreen> createState() => _UnifiedPlayerScreenState();
}

class _UnifiedPlayerScreenState extends State<UnifiedPlayerScreen>
    with TickerProviderStateMixin {
  // Mode: 0 = Song (Audio), 1 = Video
  int _mode = 0;
  
  // Video player for video mode
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;
  
  // Like status
  bool? _likeStatus;
  
  // Tab controller for UP NEXT / LYRICS / RELATED
  late TabController _tabController;
  
  // Recommendations
  List<Song> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _mode = widget.startWithVideo && widget.song.hasVideo ? 1 : 0;
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLikeStatus();
      _loadRecommendations();
      if (_mode == 1) {
        _initVideoPlayer();
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLikeStatus() async {
    try {
      final status = await ApiService.getLikeStatus(widget.song.id);
      if (mounted) setState(() => _likeStatus = status);
    } catch (e) {
      print("Error fetching like status: $e");
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final recs = await ApiService.getRecommendations(limit: 5);
      if (mounted) {
        setState(() {
          _recommendations = recs.where((s) => s.id != widget.song.id).toList();
        });
      }
    } catch (e) {
      print("Error loading recommendations: $e");
    }
  }

  Future<void> _initVideoPlayer() async {
    if (!widget.song.hasVideo) return;
    
    setState(() => _isVideoLoading = true);
    
    try {
      final streamUrl = ApiService.getStreamUrl(widget.song.id, type: 'video');
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      await _videoController!.initialize();
      
      // Get current audio position to sync
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      final audioPosition = musicProvider.position;
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: false, // We use our own controls
      );
      
      // Seek to current audio position
      if (audioPosition.inSeconds > 0) {
        await _videoController!.seekTo(audioPosition);
      }
      
      if (mounted) {
        setState(() => _isVideoLoading = false);
      }
    } catch (e) {
      print("Error initializing video: $e");
      if (mounted) {
        setState(() => _isVideoLoading = false);
      }
    }
  }

  void _onModeChanged(int newMode) {
    if (newMode == _mode) return;
    
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    
    if (newMode == 1 && widget.song.hasVideo) {
      // Switching to Video mode
      final currentPosition = musicProvider.position;
      musicProvider.pause(); // Pause audio
      
      if (_videoController == null) {
        _initVideoPlayer().then((_) {
          if (_videoController != null) {
            _videoController!.seekTo(currentPosition);
            _videoController!.play();
          }
        });
      } else {
        _videoController!.seekTo(currentPosition);
        _videoController!.play();
      }
    } else if (newMode == 0) {
      // Switching to Song (Audio) mode
      Duration? videoPosition;
      if (_videoController != null && _videoController!.value.isInitialized) {
        videoPosition = _videoController!.value.position;
        _videoController!.pause();
      }
      
      if (videoPosition != null) {
        musicProvider.seek(videoPosition);
      }
      musicProvider.resume();
    }
    
    setState(() => _mode = newMode);
  }

  Future<void> _toggleLike() async {
    try {
      if (_likeStatus == true) {
        await ApiService.dislikeSong(widget.song.id);
        setState(() => _likeStatus = false);
      } else {
        await ApiService.likeSong(widget.song.id);
        setState(() => _likeStatus = true);
      }
    } catch (e) {
      print("Error toggling like: $e");
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildContentArea(),
                  ),
                  _buildSongInfo(),
                  _buildActionButtons(),
                  _buildProgressBar(),
                  _buildControls(),
                  _buildBottomBar(), // UP NEXT button opens queue sheet
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          // Song / Video Toggle
          if (widget.song.hasVideo)
            Container(
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleButton("Song", 0),
                  _buildToggleButton("Video", 1),
                ],
              ),
            ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Show options menu
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, int modeValue) {
    final isActive = _mode == modeValue;
    return GestureDetector(
      onTap: () => _onModeChanged(modeValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    if (_mode == 1) {
      // Video Mode
      if (_isVideoLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_chewieController != null && _videoController != null && _videoController!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );
      }
      return const Center(child: Text("Video not available", style: TextStyle(color: Colors.white54)));
    } else {
      // Song Mode - Show Album Art
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.song.coverArt != null || widget.song.thumbnail != null
                ? Image.network(
                    widget.song.thumbnail ?? widget.song.coverArt!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultAlbumArt(),
                  )
                : _buildDefaultAlbumArt(),
          ),
        ),
      );
    }
  }

  Widget _buildDefaultAlbumArt() {
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.music_note, size: 80, color: Colors.white24),
      ),
    );
  }

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Text(
            widget.song.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            widget.song.artist,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _toggleLike,
            icon: Icon(
              _likeStatus == true ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: _likeStatus == true ? kPrimaryColor : Colors.white70,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              if (_likeStatus == false) {
                _toggleLike();
              } else {
                ApiService.dislikeSong(widget.song.id);
                setState(() => _likeStatus = false);
              }
            },
            icon: Icon(
              _likeStatus == false ? Icons.thumb_down : Icons.thumb_down_outlined,
              color: _likeStatus == false ? Colors.red : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Consumer<MusicProvider>(
      builder: (context, music, child) {
        final position = _mode == 1 && _videoController != null
            ? _videoController!.value.position
            : music.position;
        final duration = _mode == 1 && _videoController != null
            ? _videoController!.value.duration
            : music.duration;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()),
                  max: duration.inSeconds.toDouble().clamp(1, double.infinity),
                  onChanged: (value) {
                    final newPosition = Duration(seconds: value.toInt());
                    if (_mode == 1 && _videoController != null) {
                      _videoController!.seekTo(newPosition);
                    } else {
                      music.seek(newPosition);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(_formatDuration(duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Consumer<MusicProvider>(
      builder: (context, music, child) {
        final isPlaying = _mode == 1 && _videoController != null
            ? _videoController!.value.isPlaying
            : music.isPlaying;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.shuffle,
                  color: Colors.white70,
                  size: 24,
                ),
                onPressed: () {
                  // Shuffle not implemented yet
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                onPressed: () {
                  if (_mode == 1) {
                    _onModeChanged(0); // Switch to audio for prev
                  }
                  music.previous();
                },
              ),
              const SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 36,
                  ),
                  onPressed: () {
                    if (_mode == 1 && _videoController != null) {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                      setState(() {});
                    } else {
                      if (music.isPlaying) {
                        music.pause();
                      } else {
                        music.resume();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                onPressed: () {
                  if (_mode == 1) {
                    _onModeChanged(0); // Switch to audio for next
                  }
                  music.next();
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(
                  Icons.repeat,
                  color: Colors.white70,
                  size: 24,
                ),
                onPressed: () {
                  // Repeat not implemented yet
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return GestureDetector(
      onTap: _showQueueSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.queue_music, color: Colors.white70, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "UP NEXT",
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "${_recommendations.length} songs in queue",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 28),
          ],
        ),
      ),
    );
  }

  void _showQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    "Up Next",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Currently playing
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: kPrimaryColor.withOpacity(0.15),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: widget.song.coverArt != null || widget.song.thumbnail != null
                        ? Image.network(
                            widget.song.thumbnail ?? widget.song.coverArt!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Container(width: 48, height: 48, color: Colors.white12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Now Playing", style: TextStyle(color: kPrimaryColor, fontSize: 10, fontWeight: FontWeight.w600)),
                        Text(widget.song.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(widget.song.artist, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1),
                      ],
                    ),
                  ),
                  const Icon(Icons.graphic_eq, color: kPrimaryColor, size: 24),
                ],
              ),
            ),
            // Queue list
            Expanded(
              child: _recommendations.isEmpty
                  ? const Center(child: Text("No songs in queue", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _recommendations.length,
                      itemBuilder: (context, index) {
                        final song = _recommendations[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: song.coverArt != null || song.thumbnail != null
                                ? Image.network(
                                    song.thumbnail ?? song.coverArt!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  )
                                : Container(width: 48, height: 48, color: Colors.white12, child: const Icon(Icons.music_note, color: Colors.white24)),
                          ),
                          title: Text(song.title, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(song.artist, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: const Icon(Icons.drag_handle, color: Colors.white30),
                          onTap: () {
                            Navigator.pop(ctx);
                            final music = Provider.of<MusicProvider>(context, listen: false);
                            music.playSong(song, _recommendations);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UnifiedPlayerScreen(song: song, startWithVideo: false),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
