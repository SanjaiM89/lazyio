import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'constants.dart';
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBackgroundColor,
        primaryColor: kPrimaryColor,
        textTheme: () {
          final base = GoogleFonts.outfitTextTheme(Theme.of(context).brightness == Brightness.dark
              ? ThemeData.dark().textTheme
              : ThemeData().textTheme);
          const fallback = ['Noto Sans Tamil', 'Latha', 'Vijaya', '.SF NS', 'Roboto'];

          TextStyle withFallback(TextStyle? style) =>
              (style ?? const TextStyle()).copyWith(fontFamilyFallback: fallback);

          return base.copyWith(
            displayLarge: withFallback(base.displayLarge),
            displayMedium: withFallback(base.displayMedium),
            displaySmall: withFallback(base.displaySmall),
            headlineLarge: withFallback(base.headlineLarge),
            headlineMedium: withFallback(base.headlineMedium),
            headlineSmall: withFallback(base.headlineSmall),
            titleLarge: withFallback(base.titleLarge),
            titleMedium: withFallback(base.titleMedium),
            titleSmall: withFallback(base.titleSmall),
            bodyLarge: withFallback(base.bodyLarge),
            bodyMedium: withFallback(base.bodyMedium),
            bodySmall: withFallback(base.bodySmall),
            labelLarge: withFallback(base.labelLarge),
            labelMedium: withFallback(base.labelMedium),
            labelSmall: withFallback(base.labelSmall),
          ).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          );
        }(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          brightness: Brightness.dark,
          secondary: kSecondaryColor,
        ),
      ),
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
  final ScrollController _sidebarScrollController = ScrollController();

  Key _libraryKey = UniqueKey();
  Key _homeKey = UniqueKey();

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
          builder: (context) => UnifiedPlayerScreen(
            song: song,
            startWithVideo: startWithVideo,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _wsService.close();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  void _handleNavigation(int index, [String? query]) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return HomeScreen(key: _homeKey, onNavigate: _handleNavigation);
      case 1:
        return const LibraryScreen();
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

  // iPad layout: sidebar + content + mini player
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Divider
          Container(width: 0.5, color: Colors.white12),
          // Content
          Expanded(
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
        ],
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

  // Apple Music-style sidebar
  Widget _buildSidebar() {
    final items = [
      _SidebarItem(Icons.play_circle_fill, 'Listen Now', 0),
      _SidebarItem(Icons.library_music_rounded, 'Library', 1),
      _SidebarItem(Icons.album_rounded, 'Albums', 2),
      _SidebarItem(Icons.person_rounded, 'Artists', 3),
      _SidebarItem(Icons.upload_file_rounded, 'Upload to Telegram', 4),
    ];

    return Container(
      width: 240,
      color: kSurfaceColor,
      child: Column(
        children: [
          // App name
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimaryColor, Color(0xFFFF6B6B)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'mPlay',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = _selectedIndex == item.index;
                return _buildSidebarTile(item, isSelected);
              },
            ),
          ),
          // Settings at bottom
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildSidebarTile(
              _SidebarItem(Icons.settings_rounded, 'Settings', -1),
              false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTile(_SidebarItem item, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (item.index == -1) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            } else {
              setState(() => _selectedIndex = item.index);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? kPrimaryColor.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? kPrimaryColor : Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: kPrimaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Apple Music-style bottom nav (phone only)
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Colors.white12, width: 0.3)),
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: kPrimaryColor,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline_rounded),
              activeIcon: Icon(Icons.play_circle_fill),
              label: 'Listen Now',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_outlined),
              activeIcon: Icon(Icons.library_music_rounded),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.album_outlined),
              activeIcon: Icon(Icons.album_rounded),
              label: 'Albums',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Artists',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.upload_file_outlined),
              activeIcon: Icon(Icons.upload_file_rounded),
              label: 'Upload',
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final int index;

  _SidebarItem(this.icon, this.label, this.index);
}
