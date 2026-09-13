import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// App Configuration for Dynamic IP/Port
class AppConfig {
  static String baseUrl = '';
  static String wsUrl = '';
}

// Responsive helpers
class Layout {
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 900;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200;
  }

  static int gridColumns(BuildContext context) {
    if (isDesktop(context)) return 5;
    if (isTablet(context)) return 4;
    return 2;
  }

  static double horizontalPadding(BuildContext context) {
    if (isDesktop(context)) return 32.0;
    if (isTablet(context)) return 24.0;
    return 16.0;
  }

  static double topPadding(BuildContext context) {
    return isTablet(context) ? 24.0 : 60.0;
  }

  static double albumArtSize(BuildContext context) {
    if (isDesktop(context)) return 200.0;
    if (isTablet(context)) return 160.0;
    return 120.0;
  }
}

// Apple Music-inspired colors
const Color kPrimaryColor = Color(0xFFFA2D48); // Apple Music red
const Color kSecondaryColor = Color(0xFF9333EA);
const Color kBackgroundColor = Color(0xFF000000); // Pure black like Apple Music
const Color kSurfaceColor = Color(0xFF1C1C1E); // Apple Music card surface
const Color kSurfaceSecondary = Color(0xFF2C2C2E);

const double kPadding = 16.0;
const double kBorderRadius = 12.0;
