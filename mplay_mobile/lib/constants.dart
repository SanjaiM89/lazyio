import 'package:flutter/material.dart';

// App Configuration for Dynamic IP/Port
class AppConfig {
  // Config is loaded dynamically from SharedPreferences in main.dart
  // Default domain is lazyio.duckdns.org, but PORT must be provided by user
  static String baseUrl = ''; 
  static String wsUrl = '';  
}

// Legacy accessors (getters to maintain compatibility where possible, but const usage must change)
// Note: Files using `const baseUrl` will need to be updated to `AppConfig.baseUrl`
// We remove the const declarations to force compile errors if they were used in const contexts.

// Colors

const Color kPrimaryColor = Color(0xFFEC4899); // Pink-500
const Color kSecondaryColor = Color(0xFF9333EA); // Purple-600
const Color kBackgroundColor = Color(0xFF0F172A); // Slate-900 (Dark background)

// Constants
const double kPadding = 16.0;
const double kBorderRadius = 16.0;
