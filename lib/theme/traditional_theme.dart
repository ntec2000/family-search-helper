import 'package:flutter/material.dart';

/// 전통 한지·먹 컬러 팔레트
class HanjiColors {
  static const hanji = Color(0xFFF4ECD8);
  static const hanjiLight = Color(0xFFFAF4E3);
  static const hanjiDark = Color(0xFFE6D9B8);
  static const muk = Color(0xFF1A1410);
  static const mukLight = Color(0xFF3D2E22);
  static const mukSoft = Color(0xFF5A4A3A);
  static const ju = Color(0xFFA8261C);
  static const juSoft = Color(0xFFC8423A);
  static const cheong = Color(0xFF5D7E6F);
  static const hwang = Color(0xFFC9A14A);
}

class TraditionalTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: HanjiColors.muk,
      brightness: Brightness.light,
      primary: HanjiColors.muk,
      secondary: HanjiColors.ju,
      surface: HanjiColors.hanji,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: HanjiColors.hanji,
      textTheme: base.textTheme.apply(
        bodyColor: HanjiColors.muk,
        displayColor: HanjiColors.muk,
        fontFamily: 'serif',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HanjiColors.hanji,
        foregroundColor: HanjiColors.muk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: HanjiColors.muk,
          letterSpacing: 2,
        ),
      ),
      cardTheme: CardTheme(
        color: HanjiColors.hanjiLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: HanjiColors.mukSoft, width: 0.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HanjiColors.ju,
        foregroundColor: HanjiColors.hanji,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HanjiColors.muk,
          foregroundColor: HanjiColors.hanji,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(color: HanjiColors.mukSoft, thickness: 0.5),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: HanjiColors.muk,
        brightness: Brightness.dark,
        primary: HanjiColors.hanji,
        secondary: HanjiColors.juSoft,
      ),
      scaffoldBackgroundColor: const Color(0xFF1A1410),
    );
  }
}
