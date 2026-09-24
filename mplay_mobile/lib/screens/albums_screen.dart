import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';
import 'album_detail_screen.dart';
import 'search_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<Album> _albums = [];
  Album? _selected;
  bool _loading = true;
  bool _loadingMore = false;
  bool _scanning = false;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  static const int _pageSize = 60;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAlbums(page: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      if (!_loading && !_loadingMore && _page < _pages) {
        _loadAlbums(page: _page + 1, append: true);
      }
    }
  }

  Future<void> _loadAlbums({required int page, bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() => _loading = true);
    }
    try {
      final data = await ApiService.getAlbumsPaged(page: page, limit: _pageSize);
      final List<dynamic> raw = data['albums'] ?? [];
      final list = raw.map((j) => Album.fromJson(j as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          if (append) {
            _albums.addAll(list);
          } else {
            _albums = list;
          }
          _page = (data['page'] ?? page) as int;
          _pages = (data['pages'] ?? 1) as int;
          _total = (data['total'] ?? _albums.length) as int;
        });
      }
    } catch (e) {
      debugPrint('Error loading albums: $e');
    }
    if (mounted) setState(() {
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _openAlbum(Album album) async {
    setState(() => _loading = true);
    try {
      final full = await ApiService.getAlbum(album.id);
      if (mounted) setState(() => _selected = full ?? album);
    } catch (e) {
      debugPrint('Error opening album: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _rescan() async {
    setState(() => _scanning = true);
    try {
      await ApiService.scanTelegramChannel(force: true);
      await _loadAlbums(page: 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telegram channel rescanned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rescan failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return Scaffold(
        backgroundColor: Nocturne.background,
        body: SafeArea(
          child: AlbumDetailView(
            album: _selected!,
            onBack: () => setState(() => _selected = null),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Nocturne.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Albums',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                        _total > 0 ? '$_total albums' : 'From Telegram channel',
                        style: const TextStyle(fontSize: 13, color: Nocturne.onSurfaceVariant),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _scanning ? null : _rescan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Nocturne.border),
                      ),
                      child: _scanning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Nocturne.primary))
                          : const Text('Rescan',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Nocturne.primary)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: TopSearchBar(
                onSubmit: (q) => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SearchScreen(initialQuery: q))),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Nocturne.primary))
                  : _albums.isEmpty
                      ? const Center(
                          child: Text(
                              'No albums yet.\nAdd music to the Telegram channel, then rescan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Nocturne.outline)),
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width >= 900 ? 5 : 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _albums.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _albums.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(color: Nocturne.primary),
                                ),
                              );
                            }
                            final album = _albums[i];
                            return GestureDetector(
                              onTap: () => _openAlbum(album),
                              child: Container(
                                decoration: Nocturne.glassCard,
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: Nocturne.surfaceHighest,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        width: double.infinity,
                                        child: album.coverArt != null
                                            ? Image.network(album.coverArt!, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(
                                                    Icons.album_rounded,
                                                    size: 36,
                                                    color: Nocturne.outline))
                                            : const Icon(Icons.album_rounded,
                                                size: 36, color: Nocturne.outline),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(album.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.white)),
                                    Text('${album.songCount} songs',
                                        style: const TextStyle(
                                            color: Nocturne.onSurfaceVariant, fontSize: 11)),
                                  ],
                                ),
                              ),
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
