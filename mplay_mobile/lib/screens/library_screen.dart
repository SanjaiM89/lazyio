import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../library_provider.dart';
import '../widgets/song_tile.dart';
import '../constants.dart';
import '../providers/video_provider.dart';
import 'playlist_detail_screen.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = "";
  List<Album> _searchAlbums = [];
  List<Artist> _searchArtists = [];
  bool _searching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LibraryProvider>(context, listen: false).loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _searchDebounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _searchAlbums = [];
        _searchArtists = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final data = await ApiService.searchLibrary(val.trim());
        if (!mounted) return;
        setState(() {
          _searchAlbums = ((data['albums'] ?? []) as List)
              .map((j) => Album.fromJson(j as Map<String, dynamic>))
              .toList();
          _searchArtists = ((data['artists'] ?? []) as List)
              .map((j) => Artist.fromJson(j as Map<String, dynamic>))
              .toList();
          _searching = false;
        });
      } catch (e) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);
    final pad = Layout.horizontalPadding(context);
    final topPad = Layout.topPadding(context);
    final isTablet = Layout.isTablet(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(pad, topPad, pad, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Library',
                  style: TextStyle(
                    fontSize: isTablet ? 38 : 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _showCreatePlaylistDialog,
                ),
              ],
            ),
          ),
          // Tabs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: TabBar(
              controller: _tabController,
              labelColor: kPrimaryColor,
              unselectedLabelColor: Colors.white54,
              indicatorColor: kPrimaryColor,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: "Songs"),
                Tab(text: "Playlists"),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Consumer<LibraryProvider>(
              builder: (context, library, child) {
                if (library.isLoading && library.songs.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                }

                if (library.error != null && library.songs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text("Error: ${library.error}", style: const TextStyle(color: Colors.white54)),
                        TextButton(
                          onPressed: () => library.loadData(forceRefresh: true),
                          child: const Text("Retry"),
                        )
                      ],
                    ),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSongsTab(music, library.songs, pad),
                    _buildPlaylistsTab(library.playlists, pad),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(MusicProvider music, List<Song> songs, double pad) {
    final filteredSongs = _searchQuery.isEmpty
        ? songs
        : songs.where((s) =>
            s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.artist.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    return Column(
      children: [
        // Search
        Padding(
          padding: EdgeInsets.all(pad),
          child: Container(
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search songs, albums, artists...",
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.search, color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        // Server results: artists + albums
        if (_searchQuery.trim().length >= 2) ...[
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_searchArtists.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 8),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text("Artists", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
              ),
            ),
            SizedBox(
              height: 96,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: _searchArtists.length,
                itemBuilder: (context, i) {
                  final artist = _searchArtists[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ArtistDetailScreen(artistName: artist.name)),
                    ),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kSurfaceColor,
                              image: artist.coverArt != null
                                  ? DecorationImage(image: NetworkImage(artist.coverArt!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: artist.coverArt == null
                                ? const Icon(Icons.person, color: Colors.white38)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (_searchAlbums.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text("Albums", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: _searchAlbums.length,
                itemBuilder: (context, i) {
                  final album = _searchAlbums[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumId: album.id)),
                    ),
                    child: Container(
                      width: 110,
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
                                  ? const Center(child: Icon(Icons.album, color: Colors.white24))
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('${album.songCount} songs',
                              style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
        // Song list with infinite scroll
        Expanded(
          child: filteredSongs.isEmpty
              ? const Center(child: Text("No songs found", style: TextStyle(color: Colors.white38)))
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo is ScrollEndNotification &&
                        scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                      Provider.of<LibraryProvider>(context, listen: false).loadMoreSongs();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: filteredSongs.length + 1,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                      if (index == filteredSongs.length) {
                        final library = Provider.of<LibraryProvider>(context);
                        if (library.isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)),
                          );
                        }
                        if (!library.hasMoreSongs && filteredSongs.isNotEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text("All songs loaded", style: TextStyle(color: Colors.white38, fontSize: 12)),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      final song = filteredSongs[index];
                      return GestureDetector(
                        onLongPress: () => _showSongOptionsMenu(song),
                        child: SongTile(
                          song: song,
                          isPlaying: music.currentSong?.id == song.id,
                          onTap: () {
                            if (song.isVideo) {
                              Provider.of<MusicProvider>(context, listen: false).stop();
                              Provider.of<VideoProvider>(context, listen: false).playVideo(song);
                            } else {
                              Provider.of<VideoProvider>(context, listen: false).close();
                              music.playSong(song, filteredSongs);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab(List<Playlist> playlists, double pad) {
    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music_rounded, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text("No playlists yet", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add),
              label: const Text("Create Playlist"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(pad),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: pl)),
            ),
            leading: SizedBox(
              width: 52,
              height: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: pl.coverImage != null
                    ? Image.network(pl.coverImage!, fit: BoxFit.cover)
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [kPrimaryColor, Color(0xFFFF6B6B)]),
                        ),
                        child: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 26),
                      ),
              ),
            ),
            title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text("${pl.songCount} songs", style: const TextStyle(color: Colors.white54, fontSize: 13)),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: kSurfaceColor,
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'delete', child: Text("Delete")),
              ],
              onSelected: (val) async {
                if (val == 'delete') {
                  await ApiService.deletePlaylist(pl.id);
                  if (mounted) Provider.of<LibraryProvider>(context, listen: false).refreshData();
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceColor,
        title: const Text("New Playlist"),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Playlist name",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ApiService.createPlaylist(controller.text.trim());
                Navigator.pop(ctx);
                if (mounted) Provider.of<LibraryProvider>(context, listen: false).refreshData();
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showSongOptionsMenu(Song song) {
    final library = Provider.of<LibraryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: song.coverArt != null
                      ? Image.network(song.coverArt!, width: 50, height: 50, fit: BoxFit.cover)
                      : Container(width: 50, height: 50, color: Colors.white10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(song.artist, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: kPrimaryColor),
              title: const Text("Add to Playlist"),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylistSheet(song, library.playlists);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Rename Song"),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameSongDialog(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete Song"),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(Song song, List<Playlist> playlists) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add "${song.title}" to playlist',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No playlists yet. Create one first!", style: TextStyle(color: Colors.white54)),
              )
            else
              Expanded(
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final pl = playlists[index];
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.playlist_play, color: kPrimaryColor),
                        ),
                        title: Text(pl.name),
                        subtitle: Text("${pl.songCount} songs", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        onTap: () async {
                          await ApiService.addSongToPlaylist(pl.id, song.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Added to ${pl.name}"), backgroundColor: kPrimaryColor),
                          );
                          if (mounted) Provider.of<LibraryProvider>(context, listen: false).refreshData();
                        },
                      );
                    }),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCreatePlaylistDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text("Create New Playlist"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameSongDialog(Song song) {
    final titleController = TextEditingController(text: song.title);
    final artistController = TextEditingController(text: song.artist);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceColor,
        title: const Text("Rename Song"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Title", labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Artist", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await ApiService.updateSong(
                song.id,
                title: titleController.text.trim(),
                artist: artistController.text.trim(),
              );
              Navigator.pop(ctx);
              if (mounted) Provider.of<LibraryProvider>(context, listen: false).refreshData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Song updated"), backgroundColor: Colors.green),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceColor,
        title: const Text("Delete Song?"),
        content: Text('Are you sure you want to delete "${song.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await ApiService.deleteSong(song.id);
              Navigator.pop(ctx);
              if (mounted) Provider.of<LibraryProvider>(context, listen: false).refreshData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Song deleted"), backgroundColor: Colors.red),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
