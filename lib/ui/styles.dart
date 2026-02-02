import 'package:flutter/material.dart';

class ReachStyles {
  // COLORS
  static final Color primaryOrange = Colors.orange[800]!; 
  static const Color accentRed = Colors.redAccent;
  
  // Dark Mode Colors
  static const Color darkBackground = Colors.black;
  static const Color darkCardBg = Color(0xFF1C1C1E);
  static const Color darkText = Colors.white;
  static const Color darkSubText = Colors.grey;

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightCardBg = Colors.white;
  static const Color lightText = Colors.black87;

  // LAYOUT
  static BorderRadius cardRadius = BorderRadius.circular(24);
  static BorderRadius buttonRadius = BorderRadius.circular(16);
  static EdgeInsets pagePadding = const EdgeInsets.fromLTRB(24, 40, 24, 0);

  // TEXT STYLES
  static const TextStyle heading = TextStyle(
    fontSize: 32, 
    fontWeight: FontWeight.w900
  );
  
  static const TextStyle cardTitle = TextStyle(
    fontSize: 16, 
    fontWeight: FontWeight.bold
  );
}