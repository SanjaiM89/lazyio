import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../providers/video_provider.dart';
import '../constants.dart';

class AlbumDetailView extends StatelessWidget {
  final Album album;
  final VoidCallback? onBack;

  const AlbumDetailView({super.key, required this.album, this.onBack});

  void _play(BuildContext context, Song song, List<Song> songs) {
    if (song.isVideo) {
      Provider.of<MusicProvider>(context, listen: false).stop();
      Provider.of<VideoProvider>(context, listen: false).playVideo(song);
    } else {
      Provider.of<VideoProvider>(context, listen: false).close();
      Provider.of<MusicProvider>(context, listen: false).playSong(song, songs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = album.songs ?? [];
    final pad = Layout.horizontalPadding(context);
    final artSize = Layout.albumArtSize(context);
    final isTablet = Layout.isTablet(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, isTablet ? 24 : 60, pad, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white54),
              label: const Text('Back to Albums', style: TextStyle(color: Colors.white54)),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: kSurfaceColor,
                  image: album.coverArt != null
                      ? DecorationImage(image: NetworkImage(album.coverArt!), fit: BoxFit.cover)
                      : null,
                ),
                child: album.coverArt == null
                    ? const Center(child: Icon(Icons.album, size: 48, color: Colors.white24))
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Album', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(album.name,
                        style: TextStyle(fontSize: isTablet ? 28 : 24, fontWeight: FontWeight.w700)),
                    if (album.artist != null)
                      Text(album.artist!, style: const TextStyle(color: Colors.white54)),
                    Text('${songs.length} songs', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (songs.isEmpty)
            const Text('This album is empty.', style: TextStyle(color: Colors.white38))
          else
            ...songs.asMap().entries.map((e) {
              final i = e.key;
              final song = e.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text('${i + 1}', style: const TextStyle(color: Colors.white38)),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [song.artist, if (song.year != null) song.year.toString()].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: song.playCount > 0
                    ? Text('${song.playCount} plays', style: const TextStyle(color: Colors.white38, fontSize: 11))
                    : null,
                onTap: () => _play(context, song, songs),
              );
            }),
        ],
      ),
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  final String albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  Album? _album;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ApiService.getAlbum(widget.albumId).then((a) {
      if (mounted) setState(() {
        _album = a;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _album == null
              ? const Center(child: Text('Album not found', style: TextStyle(color: Colors.white54)))
              : AlbumDetailView(album: _album!),
    );
  }
}
