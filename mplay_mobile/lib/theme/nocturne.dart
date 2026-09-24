import 'package:flutter/material.dart';

/// Nocturne / Sonance design tokens shared by the tablet and phone layouts.
/// Matches the approved mockups: Sonance dark base (#151316), terracotta
/// primary (#ffb4a4 / container #e0836e), crimson glow accents, plus the
/// mobile crimson variant (#0c0406 bg, peach #e29a92 / coral #d96459).
class Nocturne {
  // Sonance base
  static const background = Color(0xFF151316);
  static const surface = Color(0xFF151316);
  static const surfaceLow = Color(0xFF1D1B1E);
  static const surfaceContainer = Color(0xFF211F22);
  static const surfaceHigh = Color(0xFF2C292C);
  static const surfaceHighest = Color(0xFF373437);
  static const surfaceLowest = Color(0xFF0F0D10);
  static const primary = Color(0xFFFFB4A4);
  static const primaryContainer = Color(0xFFE0836E);
  static const onPrimary = Color(0xFF5A1B0D);
  static const onPrimaryContainer = Color(0xFF5E1E10);
  static const secondaryContainer = Color(0xFF862025);
  static const tertiary = Color(0xFFFFB3B6);
  static const onSurface = Color(0xFFE7E1E5);
  static const onSurfaceVariant = Color(0xFFDAC1BC);
  static const outline = Color(0xFFA28C87);

  // Tablet doc accents
  static const dim = Color(0xFF110F12);
  static const card = Color.fromRGBO(32, 29, 34, 0.72);

  // Mobile crimson variant
  static const crimsonBg = Color(0xFF0C0406);
  static const crimsonDeep = Color(0xFF1A080D);
  static const peach = Color(0xFFE29A92);
  static const coral = Color(0xFFD96459);

  // Borders
  static const border = Color.fromRGBO(255, 255, 255, 0.08);
  static const borderBright = Color.fromRGBO(255, 255, 255, 0.15);

  static BoxDecoration get glassPanel => BoxDecoration(
        color: const Color.fromRGBO(26, 23, 28, 0.78),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
      );

  static BoxDecoration get glassDock => BoxDecoration(
        color: const Color.fromRGBO(28, 25, 30, 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.14)),
      );

  static BoxDecoration get glassInput => BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      );

  static BoxDecoration get glassCard => BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      );

  static BoxDecoration get crimsonGlass => BoxDecoration(
        color: const Color.fromRGBO(36, 12, 18, 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      );

  static ThemeData buildTheme() {
    const fallback = ['Noto Sans Tamil', 'Latha', 'Vijaya', '.SF NS', 'Roboto'];
    TextTheme withFallback(TextTheme base) {
      TextStyle wrap(TextStyle? s) =>
          (s ?? const TextStyle()).copyWith(fontFamilyFallback: fallback);
      return base.copyWith(
        displayLarge: wrap(base.displayLarge),
        displayMedium: wrap(base.displayMedium),
        displaySmall: wrap(base.displaySmall),
        headlineLarge: wrap(base.headlineLarge),
        headlineMedium: wrap(base.headlineMedium),
        headlineSmall: wrap(base.headlineSmall),
        titleLarge: wrap(base.titleLarge),
        titleMedium: wrap(base.titleMedium),
        titleSmall: wrap(base.titleSmall),
        bodyLarge: wrap(base.bodyLarge),
        bodyMedium: wrap(base.bodyMedium),
        bodySmall: wrap(base.bodySmall),
        labelLarge: wrap(base.labelLarge),
        labelMedium: wrap(base.labelMedium),
        labelSmall: wrap(base.labelSmall),
      );
    }

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        secondary: primaryContainer,
      ),
      textTheme: withFallback(ThemeData.dark().textTheme).apply(
        fontFamily: 'Plus Jakarta Sans',
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}

/// Compact descriptor pills (language / instrumental / lo-fi / tempo).
/// Renders nothing when the song carries no descriptors.
class SongBadges extends StatelessWidget {
  final dynamic song;
  final bool compact;
  final Color accent;

  const SongBadges({super.key, required this.song, this.compact = false, this.accent = Nocturne.primary});

  @override
  Widget build(BuildContext context) {
    if (song == null) return const SizedBox.shrink();
    final tags = <Widget>[];
    final lang = song.language as String?;
    if (lang != null && lang.isNotEmpty) {
      tags.add(_tag(context, lang.toUpperCase()));
    }
    if (song.isInstrumental == true) tags.add(_tag(context, 'INST'));
    if (song.isLofi == true) tags.add(_tag(context, 'LO-FI'));
    final bpm = song.bpm;
    if (!compact && bpm != null && (bpm is num) && bpm > 0) {
      tags.add(_tag(context, '${bpm.round()} BPM'));
    }
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 4, runSpacing: 4, children: tags);
  }

  Widget _tag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Nocturne.onSurfaceVariant),
      ),
    );
  }
}
