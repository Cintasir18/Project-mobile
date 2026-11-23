import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: eloraPrimary),
        scaffoldBackgroundColor: eloraBackground,
        useMaterial3: true,
      );
}
