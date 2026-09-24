import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'constants.dart';
import 'theme/nocturne.dart';
import 'music_provider.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/albums_screen.dart';
import 'screens/artists_screen.dart';
import 'screens/upload_screen.dart';
import 'websocket_service.dart';
import 'widgets/mini_player.dart';
import 'library_provider.dart';
import 'providers/video_provider.dart';
import 'widgets/video_overlay.dart';
import 'screens/unified_player_screen.dart';
import 'screens/player_screen.dart';
import 'screens/tablet/tablet_home_screen.dart';
import 'screens/tablet/tablet_player_screen.dart';
import 'widgets/tablet_chrome.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/connection_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  final prefs = await SharedPreferences.getInstance();
  final ip = prefs.getString('server_ip');
  final port = prefs.getString('server_port');

  Widget initialScreen;

  if (ip != null && port != null && ip.isNotEmpty && port.isNotEmpty) {
    AppConfig.baseUrl = 'http://$ip:$port';
    AppConfig.wsUrl = 'ws://$ip:$port/ws';
    initialScreen = const MainScreen();
  } else {
    initialScreen = const ConnectionScreen();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => VideoProvider()),
      ],
      child: MyApp(home: initialScreen),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget? home;
  const MyApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mPlay',
      debugShowCheckedModeBanner: false,
      theme: Nocturne.buildTheme(),
      home: home ?? const MainScreen(),
      routes: {
        '/home': (context) => const MainScreen(),
        '/connection': (context) => const ConnectionScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late WebSocketService _wsService;

  Key _libraryKey = UniqueKey();
  Key _homeKey = UniqueKey();

  void _goTab(int index) {
    // Re-key the Library page so Recently Added / Library always lands
    // on a fresh Songs list scrolled to the top (newest first).
    if (index == 1) _libraryKey = UniqueKey();
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService();
    _wsService.connect();

    _wsService.onLibraryUpdate = (data) {
      Provider.of<LibraryProvider>(context, listen: false).refreshData();
      setState(() {
        _homeKey = UniqueKey();
      });
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRestorePlayer();
    });

    _wsService.onMessage = (msg) {
      if (msg == 'library_updated' || msg == 'song_added') {
        Provider.of<LibraryProvider>(context, listen: false).refreshData();
        setState(() {
          _homeKey = UniqueKey();
        });
      }
    };
  }

  void _checkAndRestorePlayer() {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    if (musicProvider.shouldRestorePlayer && musicProvider.currentSong != null) {
      final song = musicProvider.currentSong!;
      final startWithVideo = musicProvider.lastPlaybackMode == 1;

      musicProvider.clearRestoreFlag();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => startWithVideo
              ? UnifiedPlayerScreen(
                  song: song,
                  startWithVideo: startWithVideo,
                )
              : Layout.isTablet(context)
                  ? const TabletPlayerScreen()
                  : const PlayerScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _wsService.close();
    super.dispose();
  }

  void _handleNavigation(int index, [String? query]) {
    _goTab(index);
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        if (Layout.isTablet(context)) {
          return TabletHomeScreen(
            onNavigate: _goTab,
            onOpenPlayer: _openTabletPlayer,
          );
        }
        return HomeScreen(key: _homeKey, onNavigate: _handleNavigation);
      case 1:
        return LibraryScreen(key: _libraryKey);
      case 2:
        return const AlbumsScreen();
      case 3:
        return const ArtistsScreen();
      case 4:
        return const UploadScreen();
      default:
        return HomeScreen(key: _homeKey, onNavigate: _handleNavigation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Layout.isTablet(context);

    if (isTablet) {
      return _buildTabletLayout();
    }
    return _buildPhoneLayout();
  }

  void _openTabletPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TabletPlayerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  // Tablet layout: ONE shared shell for every tab — floating glass
  // sidebar + content + floating pill dock. The chrome never changes
  // between pages.
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: Nocturne.surfaceLowest,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabletSidebar(
                activeTab: _selectedIndex,
                onNavigate: _goTab,
                onOpenPlayer: _openTabletPlayer,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 64),
                      child: _buildCurrentPage(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: TabletPillDock(onOpenPlayer: _openTabletPlayer),
                    ),
                    const VideoOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Phone layout: original bottom nav
  Widget _buildPhoneLayout() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kBackgroundColor,
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: Stack(
          children: [
            _buildCurrentPage(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Consumer<MusicProvider>(
                builder: (context, music, child) {
                  if (music.currentSong == null) return const SizedBox.shrink();
                  return const MiniPlayer();
                },
              ),
            ),
            const VideoOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // Floating pill bottom nav (phone only): Home / Now Playing / Library.
  Widget _buildBottomNav() {
    Widget item(IconData icon, String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 44),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 24, color: active ? Nocturne.primaryContainer : Nocturne.onSurfaceVariant),
              const SizedBox(height: 1),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: active ? Nocturne.primaryContainer : Nocturne.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    void openNowPlaying() {
      if (Provider.of<MusicProvider>(context, listen: false).currentSong == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PlayerScreen(), fullscreenDialog: true),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(29, 27, 30, 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Nocturne.surfaceHighest.withOpacity(0.6)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            item(Icons.home_rounded, 'Home', _selectedIndex == 0,
                () => _goTab(0)),
            item(Icons.play_circle_outline_rounded, 'Now Playing', false, openNowPlaying),
            item(Icons.library_music_rounded, 'Library', _selectedIndex == 1,
                () => _goTab(1)),
          ],
        ),
      ),
    );
  }
}

