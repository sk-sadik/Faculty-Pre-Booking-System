import 'package:flutter/material.dart';

/// Brand palette: deep blue primary + teal accent (Material 3).
abstract class AppColors {
  static const Color deepBlue = Color(0xFF0D47A1);
  static const Color deepBlueDark = Color(0xFF08306B);
  static const Color tealAccent = Color(0xFF009688);
  static const Color tealLight = Color(0xFF4DB6AC);

  // Status colors (shared across phases).
  static const Color pending = Color(0xFFF59E0B); // orange
  static const Color approved = Color(0xFF16A34A); // green
  static const Color rejected = Color(0xFFDC2626); // red
  static const Color rescheduled = Color(0xFF2563EB); // blue
  static const Color cancelled = Color(0xFF6B7280); // grey
  static const Color completed = Color(0xFF4B5563); // dark grey
  static const Color noShow = Color(0xFF7C3AED); // purple
}
