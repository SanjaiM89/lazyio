import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_provider.dart';
import '../library_provider.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';
import '../screens/settings_screen.dart';

/// Shared tablet chrome: the floating glass sidebar + floating transport
/// pill dock. Used by MainScreen for EVERY tablet tab so navigation and
/// playback controls never change between pages.
class TabletSidebar extends StatelessWidget {
  /// MainScreen tab index that is currently active (0 Home, 1 Library,
  /// 2 Albums, 3 Artists, 4 Upload).
  final int activeTab;
  final void Function(int tab) onNavigate;
  final VoidCallback onOpenPlayer;

  const TabletSidebar({
    super.key,
    required this.activeTab,
    required this.onNavigate,
    required this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: Nocturne.glassPanel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: const LinearGradient(
                        colors: [Nocturne.primary, Nocturne.primaryContainer]),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.music_note_rounded,
                      size: 17, color: Nocturne.onPrimary),
                ),
                const SizedBox(width: 9),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lazyio',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text('LOSSLESS AUDIO',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Nocturne.primary)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _navItem(context, Icons.home_rounded, 'Home', activeTab == 0,
                    () => onNavigate(0)),
                _navItem(context, Icons.music_note_rounded, 'Now Playing',
                    false, onOpenPlayer),
                const SizedBox(height: 10),
                _sectionLabel('Library'),
                _navItem(context, Icons.library_music_rounded, 'Library',
                    activeTab == 1, () => onNavigate(1)),
                _navItem(context, Icons.history_rounded, 'Recently Added',
                    false, () => onNavigate(1)),
                _navItem(context, Icons.mic_rounded, 'Artists',
                    activeTab == 3, () => onNavigate(3)),
                _navItem(context, Icons.album_rounded, 'Albums', activeTab == 2,
                    () => onNavigate(2)),
                const SizedBox(height: 10),
                _sectionLabel('Playlists'),
                _navItem(context, Icons.queue_music_rounded, 'All Playlists',
                    false, () => onNavigate(1)),
                Consumer<LibraryProvider>(builder: (_, lib, __) {
                  return Column(
                    children: lib.playlists.take(3).map((p) => _navItem(
                        context,
                        Icons.favorite_border_rounded,
                        p.name,
                        false,
                        () => onNavigate(1))).toList(),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Nocturne.border)),
              color: Color.fromRGBO(0, 0, 0, 0.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [Color(0xFFB7791F), Nocturne.primaryContainer]),
                  ),
                  alignment: Alignment.center,
                  child: const Text('L',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Listener',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text('Hi-Res Lossless',
                          style: TextStyle(fontSize: 10, color: Nocturne.primary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SettingsScreen())),
                  child: const Icon(Icons.settings_outlined,
                      size: 16, color: Nocturne.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: Nocturne.outline)),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label,
      bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: Nocturne.border) : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 17, color: active ? Nocturne.primary : Nocturne.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? Nocturne.primary
                          : Nocturne.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared floating transport pill dock for every tablet page.
class TabletPillDock extends StatelessWidget {
  final VoidCallback onOpenPlayer;

  const TabletPillDock({super.key, required this.onOpenPlayer});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final song = music.currentSong;
    if (song == null) return const SizedBox.shrink();

    Widget dockBtn(IconData icon, bool bright, VoidCallback onTap) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(icon,
            size: 17, color: bright ? Colors.white70 : Nocturne.outline),
        onPressed: onTap,
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: Nocturne.glassDock,
        child: Row(
          children: [
            dockBtn(Icons.shuffle_rounded, false, () {}),
            dockBtn(Icons.skip_previous_rounded, true, music.previous),
            GestureDetector(
              onTap: () =>
                  music.isPlaying ? music.pause() : music.resume(),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
                child: Icon(
                    music.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 18,
                    color: Colors.black87),
              ),
            ),
            dockBtn(Icons.skip_next_rounded, true, music.next),
            dockBtn(Icons.repeat_rounded, false, () {}),
            Container(
                width: 1,
                height: 28,
                color: Nocturne.border,
                margin: const EdgeInsets.symmetric(horizontal: 4)),
            Expanded(
              child: GestureDetector(
                onTap: onOpenPlayer,
                child: Row(
                  children: [
                    CoverArt(song: song, size: 36, radius: 8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Text(song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Nocturne.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const Text('HI-RES',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Nocturne.primary)),
                  ],
                ),
              ),
            ),
            dockBtn(Icons.more_horiz_rounded, false, () {}),
            dockBtn(Icons.lyrics_outlined, false, onOpenPlayer),
            dockBtn(Icons.queue_music_rounded, false, onOpenPlayer),
          ],
        ),
      ),
    );
  }
}
