import 'package:flutter/material.dart';

import '../api_service.dart';
import '../constants.dart';
import '../models.dart';

/// Synced lyrics for one song.
///
/// Follows playback (highlight + auto-scroll), seeks when a line is tapped and
/// re-fetches on demand. Lyrics come from the backend, which stores every
/// track once, so repeat opens never hit the lyrics service again.
class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.song,
    this.position,
    this.onSeek,
    this.scrollController,
  });

  final Song song;

  /// Current playback position. When omitted, the first line is highlighted.
  final Duration? position;

  /// Called with a line's timestamp when it is tapped (null = not seekable).
  final void Function(Duration position)? onSeek;

  /// Controller of the enclosing sheet, so dragging the sheet keeps working.
  final ScrollController? scrollController;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};
  ScrollController? _ownController;
  DateTime _userScrollingUntil = DateTime.fromMillisecondsSinceEpoch(0);
  int _requestId = 0;
  int _lastActiveIndex = -1;

  Lyrics? _lyrics;
  bool _loading = true;
  bool _failed = false;

  ScrollController get _controller =>
      widget.scrollController ?? (_ownController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _failed = false;
      _lyrics = null;
      _lastActiveIndex = -1;
      _lineKeys.clear();
    });
    try {
      final lyrics = await ApiService.getLyrics(widget.song.id, refresh: refresh);
      if (!mounted || request != _requestId) return;
      setState(() {
        _lyrics = lyrics;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _markUserScrolling() {
    _userScrollingUntil = DateTime.now().add(const Duration(seconds: 4));
  }

  /// Keep the active line centred unless the listener is scrolling themselves.
  void _followActiveLine(int activeIndex) {
    if (activeIndex < 0 || activeIndex == _lastActiveIndex) return;
    _lastActiveIndex = activeIndex;
    if (DateTime.now().isBefore(_userScrollingUntil)) return;
    final lineContext = _lineKeys[activeIndex]?.currentContext;
    if (lineContext == null) return;
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _seekTo(LyricsLine line) {
    final onSeek = widget.onSeek;
    if (onSeek == null) return;
    onSeek(Duration(milliseconds: (line.time * 1000).round()));
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification && notification.dragDetails != null) {
          _markUserScrolling();
        } else if (notification is UserScrollNotification) {
          _markUserScrolling();
        } else if (notification is OverscrollNotification) {
          // Dragging the sheet itself (content already at the edge).
          _markUserScrolling();
        }
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final lyrics = _lyrics;
    final synced = lyrics != null && lyrics.hasLines;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.lyrics_outlined, color: kPrimaryColor, size: 18),
          const SizedBox(width: 8),
          Text(
            lyrics != null ? 'LYRICS · ${lyrics.source.toUpperCase()}' : 'LYRICS',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (synced) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SYNCED',
                style: TextStyle(color: kPrimaryColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: _loading ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
            tooltip: 'Re-fetch lyrics',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_failed) {
      return _buildMessage(
        icon: Icons.cloud_off,
        title: "Couldn't load lyrics",
        hint: 'The lyrics service is unavailable right now.',
        action: _buildRetryButton(),
      );
    }
    final lyrics = _lyrics;
    if (lyrics == null) {
      return _buildMessage(
        icon: Icons.search_off,
        title: 'No lyrics found',
        hint: 'We couldn\'t find lyrics for "${widget.song.title}".',
        action: _buildRetryButton(),
      );
    }
    if (lyrics.instrumental) {
      return _buildMessage(
        icon: Icons.graphic_eq,
        title: 'Instrumental track',
        hint: 'This song has no lyrics — enjoy the music.',
      );
    }
    if (lyrics.hasLines) return _buildSynced(lyrics);
    if (lyrics.hasPlain) return _buildPlain(lyrics);
    return _buildMessage(
      icon: Icons.search_off,
      title: 'No lyrics found',
      hint: 'We couldn\'t find lyrics for "${widget.song.title}".',
      action: _buildRetryButton(),
    );
  }

  Widget _buildSynced(Lyrics lyrics) {
    final activeIndex = lyrics.activeIndex(widget.position ?? Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) => _followActiveLine(activeIndex));
    final canSeek = widget.onSeek != null;
    return SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lyrics.lines.length; index++)
            _buildLine(lyrics.lines[index], index == activeIndex, canSeek, index),
        ],
      ),
    );
  }

  Widget _buildLine(LyricsLine line, bool isActive, bool canSeek, int index) {
    final key = _lineKeys.putIfAbsent(index, () => GlobalKey());
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: canSeek ? () => _seekTo(line) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: isActive ? 19 : 17,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            height: 1.35,
          ),
          child: Text(line.text),
        ),
      ),
    );
  }

  Widget _buildPlain(Lyrics lyrics) {
    return SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Text(
        lyrics.plain,
        style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
      ),
    );
  }

  Widget _buildLoading() {
    return SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final widthFactor in const <double>[0.9, 0.7, 0.8, 0.55, 0.75, 0.65])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widthFactor,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String hint,
    Widget? action,
  }) {
    return SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return ElevatedButton.icon(
      onPressed: () => _load(refresh: true),
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Try again'),
      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
    );
  }
}
