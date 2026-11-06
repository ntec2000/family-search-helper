import 'package:flutter/material.dart';
import 'theme/traditional_theme.dart';
import 'screens/home_screen.dart';
import 'widgets/app_pinch_zoom.dart';

class FamilySearchHelperApp extends StatelessWidget {
  const FamilySearchHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가족역사 기록 도우미',
      debugShowCheckedModeBanner: false,
      theme: TraditionalTheme.light(),
      darkTheme: TraditionalTheme.dark(),
      builder: (context, child) => Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: AppPinchZoom(child: child ?? const SizedBox.shrink()))),
      home: const HomeScreen(),
    );
  }
}
