import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../providers/video_provider.dart';
import '../constants.dart';
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _artist == null
              ? const Center(child: Text('Artist not found', style: TextStyle(color: Colors.white54)))
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kSurfaceColor,
                  image: artist.coverArt != null
                      ? DecorationImage(image: NetworkImage(artist.coverArt!), fit: BoxFit.cover)
                      : null,
                ),
                child: artist.coverArt == null
                    ? const Center(child: Icon(Icons.person, size: 56, color: Colors.white24))
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Artist', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(artist.name,
                        style: TextStyle(fontSize: isTablet ? 28 : 24, fontWeight: FontWeight.w700)),
                    Text(
                      '${artist.songCount} songs • ${artist.albumCount} albums • ${_playsLabel(artist.totalPlays)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (artist.albums != null && artist.albums!.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Albums', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
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
                      width: 130,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: kSurfaceColor,
                                image: album.coverArt != null
                                    ? DecorationImage(image: NetworkImage(album.coverArt!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: album.coverArt == null
                                  ? const Center(child: Icon(Icons.album, size: 32, color: Colors.white24))
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${album.year?.toString() ?? '—'} • ${album.songCount} songs',
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          if (album.id != null)
                            const Row(
                              children: [
                                Text('Open', style: TextStyle(color: kPrimaryColor, fontSize: 11)),
                                Icon(Icons.chevron_right, color: kPrimaryColor, size: 14),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Text('Songs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (songs.isEmpty)
            const Text('No songs for this artist.', style: TextStyle(color: Colors.white38))
          else
            ...songs.asMap().entries.map((e) {
              final i = e.key;
              final song = e.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text('${i + 1}', style: const TextStyle(color: Colors.white38)),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    song.album.isNotEmpty ? song.album : null,
                    if (song.year != null) song.year.toString(),
                  ].whereType<String>().join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: song.playCount > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_playsLabel(song.playCount),
                            style: const TextStyle(color: kPrimaryColor, fontSize: 11)),
                      )
                    : null,
                onTap: () => _play(song, songs),
              );
            }),
        ],
      ),
    );
  }
}
