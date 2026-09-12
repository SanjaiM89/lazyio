import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../widgets/glass_container.dart';
import '../constants.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<Album> _albums = [];
  Album? _selected;
  bool _loading = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _loading = true);
    try {
      _albums = await ApiService.getAlbums(limit: 100);
    } catch (e) {
      debugPrint('Error loading albums: $e');
    }
    if (mounted) setState(() => _loading = false);
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
      await ApiService.scanTelegramChannel();
      await _loadAlbums();
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
      final songs = _selected!.songs ?? [];
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.arrow_back, color: Colors.white54),
                label: const Text('Back to Albums', style: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              Text(_selected!.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              if (_selected!.artist != null)
                Text(_selected!.artist!, style: const TextStyle(color: Colors.white54)),
              Text('${songs.length} songs • from Telegram', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              ...songs.map((song) => ListTile(
                    leading: const Icon(Icons.music_note, color: Colors.white54),
                    title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Provider.of<MusicProvider>(context, listen: false).playSong(song, songs),
                  )),
              if (songs.isEmpty) const Text('This album is empty.', style: TextStyle(color: Colors.white38)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Albums', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('Grouped from Telegram channel', style: TextStyle(color: Colors.white54)),
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8,
                        ),
                        itemCount: _albums.length,
                        itemBuilder: (context, i) {
                          final album = _albums[i];
                          return GestureDetector(
                            onTap: () => _openAlbum(album),
                            child: GlassContainer(
                              padding: const EdgeInsets.all(12),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
}
