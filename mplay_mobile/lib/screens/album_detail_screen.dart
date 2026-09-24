import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../providers/video_provider.dart';
import '../theme/nocturne.dart';
import '../constants.dart';
import '../widgets/nocturne_widgets.dart';
import '../widgets/song_tile.dart';

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
              icon: const Icon(Icons.arrow_back_rounded, color: Nocturne.onSurfaceVariant),
              label: const Text('Back to Albums',
                  style: TextStyle(color: Nocturne.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Nocturne.surfaceHighest,
                  border: Border.all(color: Nocturne.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: album.coverArt != null
                    ? Image.network(album.coverArt!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.album_rounded, size: 48, color: Nocturne.outline))
                    : const Icon(Icons.album_rounded, size: 48, color: Nocturne.outline),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ALBUM',
                        style: TextStyle(
                            color: Nocturne.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    Text(album.name,
                        style: TextStyle(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    if (album.artist != null)
                      Text(album.artist!,
                          style: const TextStyle(color: Nocturne.onSurfaceVariant)),
                    Text('${songs.length} songs',
                        style: const TextStyle(color: Nocturne.outline, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (songs.isEmpty)
            const Text('This album is empty.', style: TextStyle(color: Nocturne.outline))
          else
            ...songs.asMap().entries.map((e) {
              final song = e.value;
              final playing =
                  Provider.of<MusicProvider>(context, listen: false).currentSong?.id ==
                      song.id;
              return SongTile(
                song: song,
                isPlaying: playing,
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
