import 'package:flutter/material.dart';

/// Shared record-review palette for the mobile app and Flutter web.
class HanjiColors {
  static const hanji = Color(0xFFF3F7F5);
  static const hanjiLight = Color(0xFFFFFFFF);
  static const hanjiDark = Color(0xFFD9E4DE);
  static const muk = Color(0xFF20372F);
  static const mukLight = Color(0xFF344D43);
  static const mukSoft = Color(0xFF536B60);
  static const ju = Color(0xFF176B57);
  static const juSoft = Color(0xFF5BB59A);
  static const cheong = Color(0xFF357F73);
  static const hwang = Color(0xFF9A7734);
  static const gold = Color(0xFF8D703B);
}

class TraditionalTheme {
  static const _radius = 10.0;

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
        fontFamily: 'JokboHanja',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HanjiColors.hanji,
        foregroundColor: HanjiColors.muk,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: HanjiColors.muk,
          letterSpacing: 0,
          fontFamily: 'JokboHanja',
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: HanjiColors.muk,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HanjiColors.hanjiLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
      scaffoldBackgroundColor: const Color(0xFF12221C),
    );
  }
}
