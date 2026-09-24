import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../library_provider.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';
import '../providers/video_provider.dart';
import 'playlist_detail_screen.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'search_screen.dart';

class LibraryScreen extends StatefulWidget {
  /// Which tab to show first (0 Songs, 1 Playlists). Recently Added
  /// navigates here with 0 on a fresh instance (newest songs first,
  /// since the backend returns insertion order).
  final int initialTab;

  const LibraryScreen({super.key, this.initialTab = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _tab = 0;
  String _searchQuery = "";
  List<Album> _searchAlbums = [];
  List<Artist> _searchArtists = [];
  bool _searching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LibraryProvider>(context, listen: false).loadData();
    });
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: Nocturne.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 2),
              child: Text('Library',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedControl(
                      tabs: const ['Songs', 'Playlists'],
                      selected: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showCreatePlaylistDialog,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: Nocturne.surfaceHigh, shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<LibraryProvider>(
                builder: (context, library, child) {
                  if (library.isLoading && library.songs.isEmpty) {
                    return const Center(
                        child: CircularProgressIndicator(color: Nocturne.primary));
                  }

                  if (library.error != null && library.songs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: Nocturne.outline),
                          const SizedBox(height: 16),
                          Text("Error: ${library.error}",
                              style: const TextStyle(color: Nocturne.onSurfaceVariant)),
                          TextButton(
                            onPressed: () => library.loadData(forceRefresh: true),
                            child: const Text("Retry",
                                style: TextStyle(color: Nocturne.primary)),
                          )
                        ],
                      ),
                    );
                  }

                  return _tab == 0
                      ? _buildSongsTab(music, library)
                      : _buildPlaylistsTab(library.playlists);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsTab(MusicProvider music, LibraryProvider library) {
    final songs = library.songs;
    final filteredSongs = _searchQuery.isEmpty
        ? songs
        : songs
            .where((s) =>
                s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.artist.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Container(
            decoration: BoxDecoration(
                color: Nocturne.surfaceHigh, borderRadius: BorderRadius.circular(999)),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query.trim())),
                  );
                }
              },
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: "Search songs, albums, artists...",
                hintStyle: TextStyle(color: Nocturne.onSurfaceVariant, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Nocturne.onSurfaceVariant, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        if (_searchQuery.trim().length >= 2) ...[
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Nocturne.primary)),
            ),
          if (_searchArtists.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Artists",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Nocturne.onSurfaceVariant)),
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _searchArtists.length,
                itemBuilder: (context, i) {
                  final artist = _searchArtists[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ArtistDetailScreen(artistName: artist.name)),
                    ),
                    child: Container(
                      width: 68,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Nocturne.surfaceHighest,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: artist.coverArt != null
                                ? Image.network(artist.coverArt!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person_rounded, color: Nocturne.outline))
                                : const Icon(Icons.person_rounded, color: Nocturne.outline),
                          ),
                          const SizedBox(height: 4),
                          Text(artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (_searchAlbums.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Albums",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Nocturne.onSurfaceVariant)),
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _searchAlbums.length,
                itemBuilder: (context, i) {
                  final album = _searchAlbums[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumId: album.id)),
                    ),
                    child: Container(
                      width: 104,
                      margin: const EdgeInsets.only(right: 12),
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
                                  ? Image.network(album.coverArt!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.album_rounded, color: Nocturne.outline))
                                  : const Icon(Icons.album_rounded, color: Nocturne.outline),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(album.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('${album.songCount} songs',
                              style: const TextStyle(fontSize: 11, color: Nocturne.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
        Expanded(
          child: filteredSongs.isEmpty
              ? const Center(
                  child: Text("No songs found", style: TextStyle(color: Nocturne.outline)))
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
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    itemBuilder: (context, index) {
                      if (index == filteredSongs.length) {
                        final lib = Provider.of<LibraryProvider>(context);
                        if (lib.isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Nocturne.primary, strokeWidth: 2)),
                          );
                        }
                        if (!lib.hasMoreSongs && filteredSongs.isNotEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text("All songs loaded",
                                  style: TextStyle(color: Nocturne.outline, fontSize: 12)),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      final song = filteredSongs[index];
                      return GestureDetector(
                        onLongPress: () => _showSongOptionsMenu(song),
                        child: NocturneTrackRow(
                          song: song,
                          index: index,
                          active: music.currentSong?.id == song.id,
                          playing: music.currentSong?.id == song.id && music.isPlaying,
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

  Widget _buildPlaylistsTab(List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music_rounded, size: 64, color: Nocturne.outline),
            const SizedBox(height: 16),
            const Text("No playlists yet", style: TextStyle(color: Nocturne.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add_rounded, color: Nocturne.primary),
              label: const Text("Create Playlist", style: TextStyle(color: Nocturne.primary)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Nocturne.surfaceLow,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: pl)),
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: pl.coverImage != null
                      ? null
                      : const LinearGradient(
                          colors: [Nocturne.primaryContainer, Nocturne.primary]),
                  color: pl.coverImage != null ? Nocturne.surfaceHighest : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: pl.coverImage != null
                    ? Image.network(pl.coverImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.queue_music_rounded, color: Colors.white, size: 24))
                    : const Icon(Icons.queue_music_rounded, color: Colors.white, size: 24),
              ),
              title: Text(pl.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: Text("${pl.songCount} songs",
                  style: const TextStyle(color: Nocturne.onSurfaceVariant, fontSize: 13)),
              trailing: PopupMenuButton(
                icon: const Icon(Icons.more_vert_rounded, color: Nocturne.onSurfaceVariant),
                color: Nocturne.surfaceHigh,
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'delete', child: Text("Delete")),
                ],
                onSelected: (val) async {
                  if (val == 'delete') {
                    await ApiService.deletePlaylist(pl.id);
                    if (mounted) {
                      Provider.of<LibraryProvider>(context, listen: false).refreshData();
                    }
                  }
                },
              ),
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
        backgroundColor: Nocturne.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("New Playlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Playlist name",
            hintStyle: TextStyle(color: Nocturne.outline),
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
            child: const Text("Create", style: TextStyle(color: Nocturne.primary)),
          ),
        ],
      ),
    );
  }

  void _showSongOptionsMenu(Song song) {
    final library = Provider.of<LibraryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Nocturne.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CoverArt(song: song, size: 50, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(song.artist,
                          style: const TextStyle(
                              color: Nocturne.onSurfaceVariant, fontSize: 13)),
                      SongBadges(song: song, compact: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Nocturne.border),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded, color: Nocturne.primary),
              title: const Text("Add to Playlist", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylistSheet(song, library.playlists);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.blue),
              title: const Text("Rename Song", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameSongDialog(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text("Delete Song", style: TextStyle(color: Colors.white)),
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
      backgroundColor: Nocturne.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add "${song.title}" to playlist',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No playlists yet. Create one first!",
                    style: TextStyle(color: Nocturne.onSurfaceVariant)),
              )
            else
              Flexible(
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
                            color: Nocturne.primaryContainer.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.queue_music_rounded,
                              color: Nocturne.primary),
                        ),
                        title: Text(pl.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text("${pl.songCount} songs",
                            style: const TextStyle(
                                color: Nocturne.onSurfaceVariant, fontSize: 12)),
                        onTap: () async {
                          await ApiService.addSongToPlaylist(pl.id, song.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Added to ${pl.name}"),
                                backgroundColor: Nocturne.primaryContainer),
                          );
                          if (mounted) {
                            Provider.of<LibraryProvider>(context, listen: false).refreshData();
                          }
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
                icon: const Icon(Icons.add_rounded, color: Nocturne.primary),
                label: const Text("Create New Playlist",
                    style: TextStyle(color: Nocturne.primary)),
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
        backgroundColor: Nocturne.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Rename Song", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Title",
                  labelStyle: TextStyle(color: Nocturne.onSurfaceVariant)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Artist",
                  labelStyle: TextStyle(color: Nocturne.onSurfaceVariant)),
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
                const SnackBar(content: Text("Song updated")),
              );
            },
            child: const Text("Save", style: TextStyle(color: Nocturne.primary)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Song?", style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${song.title}"?',
            style: const TextStyle(color: Nocturne.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await ApiService.deleteSong(song.id);
              Navigator.pop(ctx);
              if (mounted) Provider.of<LibraryProvider>(context, listen: false).refreshData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Song deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
