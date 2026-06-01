import 'package:flutter/material.dart';
import 'theme/traditional_theme.dart';
import 'screens/home_screen.dart';

class FamilySearchHelperApp extends StatelessWidget {
  const FamilySearchHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가족역사기록 도우미',
      debugShowCheckedModeBanner: false,
      theme: TraditionalTheme.light(),
      darkTheme: TraditionalTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
