import 'package:flutter/material.dart';
import '../theme/nocturne.dart';
import '../models.dart';

/// Shared building blocks for the Nocturne tablet + phone layouts.
/// All widgets are stateless and driven by caller state (MusicProvider
/// stays the single source of truth for playback).

String fmtDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String fmtRemaining(Duration pos, Duration total) {
  final left = total - pos;
  if (left.isNegative) return '-0:00';
  return '-${fmtDuration(left)}';
}

class CoverArt extends StatelessWidget {
  final Song? song;
  final double size;
  final double radius;
  final IconData fallbackIcon;

  const CoverArt({super.key, this.song, this.size = 48, this.radius = 12, this.fallbackIcon = Icons.music_note});

  @override
  Widget build(BuildContext context) {
    final url = song?.coverArt ?? song?.thumbnail;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Nocturne.surfaceHighest,
        border: Border.all(color: Nocturne.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url.isNotEmpty)
          ? Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: Nocturne.outline))
          : Icon(fallbackIcon, color: Nocturne.outline),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.radius = 28, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? const Color.fromRGBO(26, 23, 28, 0.78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Nocturne.border),
      ),
      child: child,
    );
  }
}

/// Pulsing "96kHz Lossless" style chip.
class HiResBadge extends StatefulWidget {
  final String label;
  const HiResBadge({super.key, this.label = '96kHz Lossless'});

  @override
  State<HiResBadge> createState() => _HiResBadgeState();
}

class _HiResBadgeState extends State<HiResBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Nocturne.primaryContainer.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Nocturne.primaryContainer.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _c.drive(Tween(begin: 1.0, end: 0.3)),
            child: Container(width: 6, height: 6,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Nocturne.primaryContainer)),
          ),
          const SizedBox(width: 5),
          Text(widget.label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Nocturne.primaryContainer)),
        ],
      ),
    );
  }
}

/// Animated equalizer bars for the active row.
class EqBars extends StatefulWidget {
  final Color color;
  const EqBars({super.key, this.color = Nocturne.primary});

  @override
  State<EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = (_c.value + i * 0.33) % 1.0;
              return Container(
                width: 3,
                height: 4 + t * 10,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Track row: index (or eq when active) / title+artist+badges / duration.
/// Matches the mockups on both tablet and phone.
class NocturneTrackRow extends StatelessWidget {
  final Song song;
  final int index;
  final bool active;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  const NocturneTrackRow({
    super.key,
    required this.song,
    required this.index,
    this.active = false,
    this.playing = false,
    required this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Nocturne.primaryContainer.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: Nocturne.primaryContainer.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: active && playing
                  ? const Center(child: EqBars())
                  : Text('${index + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Nocturne.outline)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active ? Nocturne.primary : Colors.white)),
                  const SizedBox(height: 1),
                  Text(song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: active ? Nocturne.primary.withOpacity(0.8) : Nocturne.onSurfaceVariant)),
                  SongBadges(song: song, compact: true),
                ],
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Nocturne.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('HI-RES',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Nocturne.primary)),
              ),
            Text(fmtDuration(Duration(seconds: song.duration.round())),
                style: const TextStyle(fontSize: 12, color: Nocturne.outline)),
            if (onMore != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.more_horiz, size: 18, color: Nocturne.outline),
                onPressed: onMore,
              ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.count, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(count!,
                    style: const TextStyle(fontSize: 12, color: Nocturne.outline)),
              ],
            ],
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(fontSize: 12, color: Nocturne.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Segmented pill control (Nocturne Music / Library, Queue / Lyrics / Specs).
class SegmentedControl extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  const SegmentedControl({super.key, required this.tabs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Nocturne.border),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.black87 : Nocturne.onSurfaceVariant)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Global search bar pinned at the top of every tab page.
/// The host screen pushes SearchScreen in [onSubmit].
class TopSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onSubmit;

  const TopSearchBar(
      {super.key,
      this.hintText = 'Artists, Songs, Lyrics, and More',
      required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Nocturne.surfaceHigh, borderRadius: BorderRadius.circular(999)),
      child: TextField(
        onSubmitted: (q) {
          if (q.trim().isEmpty) return;
          onSubmit(q.trim());
        },
        style: const TextStyle(fontSize: 13, color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 12, color: Nocturne.onSurfaceVariant),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: Nocturne.onSurfaceVariant),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}
class NocturneSeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color activeColor;

  const NocturneSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.activeColor = Nocturne.primary,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final posMs = position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 0);
    final pct = totalMs > 0 ? posMs / totalMs : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: activeColor,
            inactiveTrackColor: Colors.white.withOpacity(0.12),
            thumbColor: activeColor,
          ),
          child: Slider(
            value: pct.clamp(0.0, 1.0),
            onChanged: (v) => onSeek(Duration(milliseconds: (v * totalMs).round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmtDuration(position),
                  style: const TextStyle(fontSize: 11, color: Nocturne.outline, fontFeatures: [FontFeature.tabularFigures()])),
              Text(fmtRemaining(position, duration),
                  style: const TextStyle(fontSize: 11, color: Nocturne.outline, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      ],
    );
  }
}
