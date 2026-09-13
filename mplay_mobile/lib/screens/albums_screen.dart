import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../constants.dart';
import 'album_detail_screen.dart';

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
          SnackBar(content: Text('Rescan failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: AlbumDetailView(
          album: _selected!,
          onBack: () => setState(() => _selected = null),
        ),
      );
    }

    final pad = Layout.horizontalPadding(context);
    final topPad = Layout.topPadding(context);
    final cols = Layout.gridColumns(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, topPad, pad, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Albums',
                      style: TextStyle(
                        fontSize: isTablet(context) ? 38 : 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      _total > 0 ? '$_total albums' : 'From Telegram channel',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _scanning ? null : _rescan,
                  child: Text(_scanning ? 'Scanning...' : 'Rescan', style: const TextStyle(color: kPrimaryColor)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _albums.isEmpty
                    ? const Center(
                        child: Text('No albums yet.\nAdd music to the Telegram channel, then rescan.',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 100),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _albums.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _albums.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: kPrimaryColor),
                              ),
                            );
                          }
                          final album = _albums[i];
                          return GestureDetector(
                            onTap: () => _openAlbum(album),
                            child: Container(
                              decoration: BoxDecoration(
                                color: kSurfaceColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.white10,
                                        image: album.coverArt != null
                                            ? DecorationImage(image: NetworkImage(album.coverArt!), fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: album.coverArt == null
                                          ? const Center(child: Icon(Icons.album, size: 40, color: Colors.white24))
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${album.songCount} songs', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  bool isTablet(BuildContext context) => Layout.isTablet(context);
}
