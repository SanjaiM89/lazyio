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
import 'album_detail_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artistName;

  const ArtistDetailScreen({super.key, required this.artistName});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  Artist? _artist;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ApiService.getArtist(widget.artistName).then((a) {
      if (mounted) setState(() {
        _artist = a;
        _loading = false;
      });
    });
  }

  void _play(Song song, List<Song> songs) {
    if (song.isVideo) {
      Provider.of<MusicProvider>(context, listen: false).stop();
      Provider.of<VideoProvider>(context, listen: false).playVideo(song);
    } else {
      Provider.of<VideoProvider>(context, listen: false).close();
      Provider.of<MusicProvider>(context, listen: false).playSong(song, songs);
    }
  }

  String _playsLabel(int n) => n == 1 ? '1 play' : '$n plays';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Nocturne.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Nocturne.primary))
          : _artist == null
              ? const Center(
                  child: Text('Artist not found',
                      style: TextStyle(color: Nocturne.onSurfaceVariant)))
              : _buildBody(_artist!),
    );
  }

  Widget _buildBody(Artist artist) {
    final songs = artist.songs ?? [];
    final pad = Layout.horizontalPadding(context);
    final artSize = Layout.albumArtSize(context);
    final isTablet = Layout.isTablet(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: artSize,
                height: artSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Nocturne.surfaceHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: artist.coverArt != null
                    ? Image.network(artist.coverArt!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded, size: 56, color: Nocturne.outline))
                    : const Icon(Icons.person_rounded, size: 56, color: Nocturne.outline),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ARTIST',
                        style: TextStyle(
                            color: Nocturne.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    Text(artist.name,
                        style: TextStyle(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text(
                      '${artist.songCount} songs • ${artist.albumCount} albums • ${_playsLabel(artist.totalPlays)}',
                      style: const TextStyle(color: Nocturne.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (artist.albums != null && artist.albums!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Albums'),
            const SizedBox(height: 4),
            SizedBox(
              height: 176,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: artist.albums!.length,
                itemBuilder: (context, i) {
                  final album = artist.albums![i];
                  return GestureDetector(
                    onTap: album.id == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumId: album.id!)),
                            ),
                    child: Container(
                      width: 126,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Nocturne.surfaceHighest,
                              ),
                              clipBehavior: Clip.antiAlias,
                              width: double.infinity,
                              child: album.coverArt != null
                                  ? Image.network(album.coverArt!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.album_rounded, color: Nocturne.outline))
                                  : const Icon(Icons.album_rounded, color: Nocturne.outline),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(album.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                          Text('${album.year?.toString() ?? '—'} • ${album.songCount} songs',
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
          const SizedBox(height: 24),
          const SectionHeader(title: 'Songs'),
          const SizedBox(height: 4),
          if (songs.isEmpty)
            const Text('No songs for this artist.', style: TextStyle(color: Nocturne.outline))
          else
            ...songs.map((song) {
              final playing =
                  Provider.of<MusicProvider>(context, listen: false).currentSong?.id ==
                      song.id;
              return SongTile(
                song: song,
                isPlaying: playing,
                onTap: () => _play(song, songs),
              );
            }),
        ],
      ),
    );
  }
}
