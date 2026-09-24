import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';
import 'artist_detail_screen.dart';
import 'search_screen.dart';

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
    return Scaffold(
      backgroundColor: Nocturne.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Artists',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    _total > 0 ? '$_total artists' : 'From your Telegram channel',
                    style: const TextStyle(fontSize: 13, color: Nocturne.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  TopSearchBar(
                    onSubmit: (q) => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SearchScreen(initialQuery: q))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Nocturne.primary))
                  : _artists.isEmpty
                      ? const Center(
                          child: Text('No artists yet.\nAdd music to the Telegram channel, then rescan.',
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
                            childAspectRatio: 0.82,
                          ),
                          itemCount: _artists.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _artists.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(color: Nocturne.primary),
                                ),
                              );
                            }
                            final artist = _artists[i];
                            return GestureDetector(
                              onTap: () => _openArtist(artist),
                              child: Container(
                                decoration: Nocturne.glassCard,
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Nocturne.surfaceHighest,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: artist.coverArt != null
                                              ? Image.network(artist.coverArt!, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Icon(
                                                      Icons.person_rounded,
                                                      size: 36,
                                                      color: Nocturne.outline))
                                              : const Icon(Icons.person_rounded,
                                                  size: 36, color: Nocturne.outline),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(artist.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                                    Text('${artist.songCount} songs',
                                        style: const TextStyle(color: Nocturne.onSurfaceVariant, fontSize: 11)),
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
