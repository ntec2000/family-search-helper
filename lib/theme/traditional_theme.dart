import 'package:flutter/material.dart';

/// 전통 한지·먹 컬러 팔레트 (모던 리프레시)
class HanjiColors {
  static const hanji = Color(0xFFF6EFDD);
  static const hanjiLight = Color(0xFFFCF7EA);
  static const hanjiDark = Color(0xFFEADFC2);
  static const muk = Color(0xFF211A14);
  static const mukLight = Color(0xFF3D2E22);
  static const mukSoft = Color(0xFF6B5A48);
  static const ju = Color(0xFFB23A2E);
  static const juSoft = Color(0xFFCD5B4F);
  static const cheong = Color(0xFF5D7E6F);
  static const hwang = Color(0xFFC9A14A);
  static const gold = Color(0xFFB89150);
}

class TraditionalTheme {
  static const _radius = 16.0;

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: HanjiColors.ju,
      brightness: Brightness.light,
      primary: HanjiColors.muk,
      onPrimary: HanjiColors.hanji,
      secondary: HanjiColors.ju,
      surface: HanjiColors.hanjiLight,
      surfaceContainerHighest: HanjiColors.hanjiDark,
      onSurface: HanjiColors.muk,
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
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: HanjiColors.muk,
          letterSpacing: 1.5,
          fontFamily: 'serif',
        ),
      ),
      cardTheme: CardThemeData(
        color: HanjiColors.hanjiLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: HanjiColors.hanjiDark, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HanjiColors.ju,
        foregroundColor: HanjiColors.hanji,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HanjiColors.muk,
          foregroundColor: HanjiColors.hanji,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HanjiColors.muk,
          foregroundColor: HanjiColors.hanji,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HanjiColors.muk,
          side: const BorderSide(color: HanjiColors.mukSoft, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HanjiColors.hanjiLight,
        side: const BorderSide(color: HanjiColors.hanjiDark),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(color: HanjiColors.muk),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HanjiColors.hanjiLight,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HanjiColors.hanjiDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HanjiColors.hanjiDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HanjiColors.ju, width: 1.5),
        ),
        labelStyle: const TextStyle(color: HanjiColors.mukSoft),
        hintStyle: const TextStyle(color: HanjiColors.mukSoft),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: HanjiColors.mukSoft,
        textColor: HanjiColors.muk,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: HanjiColors.muk,
        unselectedLabelColor: HanjiColors.mukSoft,
        indicatorColor: HanjiColors.ju,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      dividerTheme:
          const DividerThemeData(color: HanjiColors.hanjiDark, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HanjiColors.muk,
        contentTextStyle: const TextStyle(color: HanjiColors.hanji),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: HanjiColors.ju,
        brightness: Brightness.dark,
        primary: HanjiColors.hanji,
        secondary: HanjiColors.juSoft,
      ),
      scaffoldBackgroundColor: const Color(0xFF1A1410),
    );
  }
}
