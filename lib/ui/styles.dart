import 'package:flutter/material.dart';

class ReachStyles {
  // ---------------------------------------------------------------------------
  // STATIC ACCENTS
  // ---------------------------------------------------------------------------
  static final Color primaryOrange = Colors.orange[800]!;
  static const Color accentRed = Colors.redAccent;

  // ---------------------------------------------------------------------------
  // DYNAMIC BACKGROUNDS (DARK)
  // ---------------------------------------------------------------------------
  static Color get dynamicDarkBg {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return const Color(0xFF0F172A); // Morning: Deep Navy
    if (hour >= 12 && hour < 18) return const Color(0xFF1C1C1E); // Day: Standard Grey
    return const Color(0xFF000000); // Night: Pure Black
  }

  // ---------------------------------------------------------------------------
  // DYNAMIC CARD COLORS (DARK)
  // ---------------------------------------------------------------------------
  static Color get dynamicDarkCard {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return const Color(0xFF1E293B); // Morning: Slate Card
    if (hour >= 12 && hour < 18) return const Color(0xFF2C2C2E); // Day: Standard Grey Card
    return const Color(0xFF121212); // Night: Darker Card
  }

  // ---------------------------------------------------------------------------
  // DYNAMIC BACKGROUNDS (LIGHT)
  // ---------------------------------------------------------------------------
  static Color get dynamicLightBg {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return const Color(0xFFFFF9E6); // Sunrise: Peach
    if (hour >= 17 && hour < 20) return const Color(0xFFFFF0ED); // Sunset: Rose
    return const Color(0xFFF5F5F7); // Standard Day
  }

  // FIX: FALLBACK STATIC COLORS (Restored)
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightCard = Colors.white;

  // ---------------------------------------------------------------------------
  // TEXT COLORS
  // ---------------------------------------------------------------------------
  static const Color darkText = Colors.white;
  static const Color lightText = Colors.black87;

  // ---------------------------------------------------------------------------
  // LAYOUT & TYPOGRAPHY
  // ---------------------------------------------------------------------------
  static BorderRadius cardRadius = BorderRadius.circular(24);
  static BorderRadius buttonRadius = BorderRadius.circular(16);
  static EdgeInsets pagePadding = const EdgeInsets.fromLTRB(24, 40, 24, 0);

  static const TextStyle heading = TextStyle(
    fontSize: 32, 
    fontWeight: FontWeight.w900
  );
  
  static const TextStyle cardTitle = TextStyle(
    fontSize: 16, 
    fontWeight: FontWeight.bold
  );
}