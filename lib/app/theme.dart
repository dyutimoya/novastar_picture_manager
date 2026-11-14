import 'package:flutter/material.dart';

class AppTheme {
  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF141419),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF60A5FA),
      surface: Color(0xFF1E1E26),
      surfaceContainerHighest: Color(0xFF262632),
      onPrimary: Colors.white,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E26),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xFF3B82F6),
      inactiveTrackColor: Colors.white12,
      thumbColor: Colors.white,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      trackHeight: 3,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1E26), elevation: 8),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF3B82F6);
        }
        return Colors.transparent;
      }),
      side: const BorderSide(color: Colors.white38, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}
