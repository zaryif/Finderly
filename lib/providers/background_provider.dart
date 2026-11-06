import 'package:flutter/material.dart';
import 'package:finderly/database/local_db.dart';

enum AppBackground {
  darkDots(
    label: 'Dark Dots',
    assetName: 'bg_dark_dots.jpg',
    isDark: true,
    solidColor: Color(0xFF0D0D0E),
  ),
  lightDots(
    label: 'Light Dots',
    assetName: 'bg_light_dots.jpg',
    isDark: false,
    solidColor: Colors.white,
  ),
  gray(
    label: 'Normal Gray',
    assetName: null,
    isDark: false,
    solidColor: Color(0xFFF2F2F7),
  ),
  white(
    label: 'Normal White',
    assetName: null,
    isDark: false,
    solidColor: Colors.white,
  ),
  pureBlack(
    label: 'Pure Black',
    assetName: null,
    isDark: true,
    solidColor: Colors.black,
  );

  final String label;
  final String? assetName;
  final bool isDark;
  final Color solidColor;

  const AppBackground({
    required this.label,
    required this.assetName,
    required this.isDark,
    required this.solidColor,
  });

  BoxDecoration get decoration {
    if (assetName != null) {
      return BoxDecoration(
        color: solidColor,
        image: DecorationImage(
          image: AssetImage('assets/images/$assetName'),
          fit: BoxFit.cover,
          repeat: ImageRepeat.repeat,
        ),
      );
    }
    return BoxDecoration(color: solidColor);
  }

  Color get textColor => isDark ? Colors.white : const Color(0xFF1D1D1F);
  Color get subtextColor => isDark ? Colors.grey.shade400 : const Color(0xFF86868B);
  Color get iconColor => isDark ? Colors.white : const Color(0xFF1D1D1F);
  Color get cardColor => isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get borderColor => isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
}

class BackgroundProvider extends ChangeNotifier {
  static const _key = 'app_background_theme';
  AppBackground _current = AppBackground.darkDots;

  AppBackground get current => _current;
  bool get isDark => _current.isDark;

  BackgroundProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final saved = await LocalDB.instance.getSetting(_key);
      if (saved != null) {
        _current = AppBackground.values.firstWhere(
          (b) => b.name == saved,
          orElse: () => AppBackground.darkDots,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading background preference: $e');
    }
  }

  Future<void> setBackground(AppBackground bg) async {
    if (_current == bg) return;
    _current = bg;
    notifyListeners();
    try {
      await LocalDB.instance.setSetting(_key, bg.name);
    } catch (e) {
      debugPrint('Error saving background preference: $e');
    }
  }
}

