import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finderly/theme/app_theme.dart';
import 'package:finderly/providers/background_provider.dart';
import 'package:finderly/screens/home_screen.dart';

class FinderlyApp extends StatelessWidget {
  const FinderlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BackgroundProvider>(
      builder: (context, bgProvider, _) {
        return MaterialApp(
          title: 'Finderly',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: bgProvider.isDark ? ThemeMode.dark : ThemeMode.light,
          home: const HomeScreen(),
        );
      },
    );
  }
}
