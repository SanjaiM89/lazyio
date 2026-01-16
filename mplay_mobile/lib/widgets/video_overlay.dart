import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../providers/video_provider.dart';
import '../constants.dart';

class VideoOverlay extends StatelessWidget {
  const VideoOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        if (provider.currentVideo == null) return const SizedBox.shrink();

        final size = MediaQuery.of(context).size;
        final isMinimized = provider.isMinimized;

        // Dimensions for mini player
        final double miniHeight = 80;
        final double miniWidth = size.width; // Docked at bottom, full width usually or small float
        // Let's match the design of MiniPlayer (audio) roughly: floating bar or docked box
        // But user asked for "Video to MiniPlayer", usually video miniplayers are floating boxes (PiP style)
        // Let's go with a floating box at bottom right for true PiP feel, or a bottom bar.
        // User said "scroll down ... go to mini player".
        // Let's stick to a Docked Bottom Bar design similar to the Audio MiniPlayer for consistency initially,
        // OR a classic YouTube PiP (bottom right).
        // Given "Mini Player" usually implies the bottom bar in this app context, let's try a transform.
        
        // Actually, YouTube mobile minimizes to a bottom strip.
        // Let's implement YouTube style: Full screen -> Bottom Strip.
        
        final double height = isMinimized ? miniHeight : size.height;
        final double width = isMinimized ? size.width : size.width;
        final double top = isMinimized ? size.height - miniHeight - kBottomNavigationBarHeight - 20 : 0; 
        // Note: kBottomNavigationBarHeight + some padding if needed. 
        // If we are above the bottom nav, we need to know its height. 
        // Assuming standard scaffold with bottom nav.
        
        // We'll place it in a Stack in main.dart, so 'top' controls position.
        
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: isMinimized ? size.height - 140 : 0, // Approx height of bottom nav + buffer
          left: 0,
          right: 0,
          height: height,
          child: Material(
            elevation: isMinimized ? 8 : 0,
            color: Colors.black,
            child: isMinimized 
               ? _buildMiniPlayer(context, provider)
               : _buildFullScreenPlayer(context, provider),
          ),
        );
      },
    );
  }

  Widget _buildFullScreenPlayer(BuildContext context, VideoProvider provider) {
    return Stack(
      children: [
        if (provider.chewieController != null && provider.videoPlayerController!.value.isInitialized)
          Chewie(controller: provider.chewieController!)
        else
          const Center(child: CircularProgressIndicator()),
          
        // Drag to minimize gesture
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 300) {
                 provider.minimize();
              }
            },
            child: Container(color: Colors.transparent),
          ),
        ),
        
        // Back Button to Minimize
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              onPressed: () => provider.minimize(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPlayer(BuildContext context, VideoProvider provider) {
    final song = provider.currentVideo!;
    return GestureDetector(
      onTap: () => provider.maximize(),
      onVerticalDragEnd: (details) {
         if (details.primaryVelocity! < -300) {
           provider.maximize();
         }
      },
      child: Container(
        color: const Color(0xFF1E1E1E),
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            // Mini Video View
            SizedBox(
              width: 120,
              height: 72,
              child: provider.videoPlayerController != null && provider.videoPlayerController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: provider.videoPlayerController!.value.aspectRatio,
                      child: VideoPlayer(provider.videoPlayerController!),
                    )
                  : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            const SizedBox(width: 8),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Controls
            IconButton(
              icon: Icon(
                provider.videoPlayerController != null && provider.videoPlayerController!.value.isPlaying 
                  ? Icons.pause 
                  : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                if (provider.videoPlayerController!.value.isPlaying) {
                  provider.videoPlayerController!.pause();
                } else {
                  provider.videoPlayerController!.play();
                }
                // Force rebuild to update icon
                provider.notifyListeners(); 
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => provider.close(),
            ),
          ],
        ),
      ),
    );
  }
}
