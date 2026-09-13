import 'package:flutter/material.dart';
import '../models.dart';
import '../constants.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isPlaying = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = Layout.isTablet(context);
    final artSize = isTablet ? 52.0 : 50.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: isTablet ? 10 : 8),
        decoration: BoxDecoration(
          color: isPlaying
              ? kPrimaryColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Cover Art
            SizedBox(
              width: artSize,
              height: artSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.coverArt != null && song.coverArt!.isNotEmpty
                    ? Image.network(
                        song.coverArt!,
                        width: artSize,
                        height: artSize,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: kSurfaceColor,
                          child: const Icon(Icons.music_note, color: Colors.white38),
                        ),
                      )
                    : Container(
                        color: kSurfaceColor,
                        child: const Icon(Icons.music_note, color: Colors.white38),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: isPlaying ? kPrimaryColor : Colors.white,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: isPlaying ? kPrimaryColor.withOpacity(0.7) : Colors.white54,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Playing indicator or duration
            if (isPlaying)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.equalizer_rounded, color: kPrimaryColor, size: 16),
              )
            else
              Text(
                _formatDuration(song.duration),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),

            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}
