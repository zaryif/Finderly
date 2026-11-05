import 'package:flutter/material.dart';
import 'package:finderly/theme/app_theme.dart';
import 'package:finderly/screens/home_screen.dart';

class FinderlyApp extends StatelessWidget {
  const FinderlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finderly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

