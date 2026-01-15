import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../models.dart';
import '../music_provider.dart';
import '../widgets/song_tile.dart';
import '../constants.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    try {
      final songs = await ApiService.getSongs();
      if (mounted) {
        setState(() {
          _songs = songs;
          _filteredSongs = songs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      print("Error loading library: $e");
    }
  }

  void _filterSongs(String query) {
    if (query.isEmpty) {
      setState(() => _filteredSongs = _songs);
    } else {
      setState(() {
        _filteredSongs = _songs.where((s) => 
          s.title.toLowerCase().contains(query.toLowerCase()) || 
          s.artist.toLowerCase().contains(query.toLowerCase())
        ).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Your Library", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _filterSongs,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search songs...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : _filteredSongs.isEmpty 
                ? const Center(child: Text("No songs found", style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    itemCount: _filteredSongs.length,
                    // Add padding at bottom for miniplayer
                    padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16), 
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      return SongTile(
                        song: song,
                        isPlaying: music.currentSong?.id == song.id,
                        onTap: () {
                          music.playSong(song, _filteredSongs);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
