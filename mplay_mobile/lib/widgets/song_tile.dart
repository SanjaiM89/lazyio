import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/nocturne.dart';
import 'nocturne_widgets.dart';

/// Track row restyled to the Nocturne system (cover, title + badges,
/// duration / equalizer, optional trailing). API unchanged so all
/// existing call sites keep working.
class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;
  final Widget? trailing;
  final int? index;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isPlaying = false,
    this.trailing,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isPlaying
              ? Nocturne.primaryContainer.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(color: Nocturne.primaryContainer.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            CoverArt(song: song, size: 48, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isPlaying ? Nocturne.primary : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: isPlaying
                          ? Nocturne.primary.withOpacity(0.8)
                          : Nocturne.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SongBadges(song: song, compact: true),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isPlaying)
              const EqBars()
            else
              Text(
                fmtDuration(Duration(seconds: song.duration.round())),
                style: const TextStyle(color: Nocturne.outline, fontSize: 12),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
