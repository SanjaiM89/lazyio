import 'package:flutter/material.dart';
import '../models.dart';
import 'glass_container.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPlaying 
              ? const Color(0xFFEC4899).withOpacity(0.15) 
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: isPlaying 
              ? Border.all(color: const Color(0xFFEC4899).withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // Cover Art - Rounded corners like Apple Music
            SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: song.coverArt != null && song.coverArt!.isNotEmpty
                    ? Image.network(
                        song.coverArt!, 
                        width: 56, 
                        height: 56, 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white.withOpacity(0.08),
                          child: const Icon(Icons.music_note, color: Colors.white38),
                        ),
                      )
                    : Container(
                        color: Colors.white.withOpacity(0.08),
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
                      fontWeight: FontWeight.w600, 
                      fontSize: 16,
                      color: isPlaying ? const Color(0xFFEC4899) : Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: isPlaying ? const Color(0xFFEC4899).withOpacity(0.7) : Colors.white54, 
                      fontSize: 14,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.equalizer_rounded, 
                  color: Color(0xFFEC4899), 
                  size: 18,
                ),
              )
            else
              Text(
                _formatDuration(song.duration),
                style: const TextStyle(color: Colors.white38, fontSize: 13),
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
    return '${min}:${sec.toString().padLeft(2, '0')}';
  }
}
