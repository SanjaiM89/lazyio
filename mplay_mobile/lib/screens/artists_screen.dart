import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../constants.dart';
import 'artist_detail_screen.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  List<Artist> _artists = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  static const int _pageSize = 60;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadArtists(page: 1);
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
        _loadArtists(page: _page + 1, append: true);
      }
    }
  }

  Future<void> _loadArtists({required int page, bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() => _loading = true);
    }
    try {
      final data = await ApiService.getArtistsPaged(page: page, limit: _pageSize);
      final List<dynamic> raw = data['artists'] ?? [];
      final list = raw.map((j) => Artist.fromJson(j as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          if (append) {
            _artists.addAll(list);
          } else {
            _artists = list;
          }
          _page = (data['page'] ?? page) as int;
          _pages = (data['pages'] ?? 1) as int;
          _total = (data['total'] ?? _artists.length) as int;
        });
      }
    } catch (e) {
      debugPrint('Error loading artists: $e');
    }
    if (mounted) setState(() {
      _loading = false;
      _loadingMore = false;
    });
  }

  void _openArtist(Artist artist) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArtistDetailScreen(artistName: artist.name)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Artists',
                  style: TextStyle(
                    fontSize: Layout.isTablet(context) ? 38 : 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  _total > 0 ? '$_total artists' : 'From your Telegram channel',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _artists.isEmpty
                    ? const Center(
                        child: Text('No artists yet.\nAdd music to the Telegram channel, then rescan.',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 100),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: _artists.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _artists.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: kPrimaryColor),
                              ),
                            );
                          }
                          final artist = _artists[i];
                          return GestureDetector(
                            onTap: () => _openArtist(artist),
                            child: Container(
                              decoration: BoxDecoration(
                                color: kSurfaceColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white10,
                                        image: artist.coverArt != null
                                            ? DecorationImage(image: NetworkImage(artist.coverArt!), fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: artist.coverArt == null
                                          ? const Center(child: Icon(Icons.person, size: 40, color: Colors.white24))
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${artist.songCount} songs', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
}
