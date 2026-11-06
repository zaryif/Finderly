import 'package:flutter/material.dart';

enum FolderColor {
  blue(Color(0xFF4A9EF5), Color(0xFF3A7EC5), Color(0xFF6AB4FF)),
  purple(Color(0xFF9B59B6), Color(0xFF7D4792), Color(0xFFB574D0)),
  pink(Color(0xFFE84393), Color(0xFFC03578), Color(0xFFF06BAF)),
  red(Color(0xFFE74C3C), Color(0xFFC0392B), Color(0xFFF07060)),
  orange(Color(0xFFF39C12), Color(0xFFD4850F), Color(0xFFF5B041)),
  yellow(Color(0xFFF1C40F), Color(0xFFD4AC0D), Color(0xFFF4D03F)),
  green(Color(0xFF2ECC71), Color(0xFF27AE60), Color(0xFF58D68D)),
  gray(Color(0xFF95A5A6), Color(0xFF7F8C8D), Color(0xFFAEB6B7)),
  teal(Color(0xFF00B4D8), Color(0xFF0077B6), Color(0xFF90E0EF)),
  cyan(Color(0xFF00C4DF), Color(0xFF0096B4), Color(0xFF7CE8F7)),
  indigo(Color(0xFF5C6BC0), Color(0xFF3949AB), Color(0xFF7986CB)),
  lavender(Color(0xFF9F8FEF), Color(0xFF7A64D8), Color(0xFFC7B9FF)),
  mint(Color(0xFF2DD4BF), Color(0xFF0D9488), Color(0xFF5EEAD4)),
  coral(Color(0xFFFF7043), Color(0xFFF4511E), Color(0xFFFF8A65)),
  amber(Color(0xFFFFB300), Color(0xFFFF8F00), Color(0xFFFFCA28)),
  brown(Color(0xFF8D6E63), Color(0xFF6D4C41), Color(0xFFA1887F)),
  slate(Color(0xFF78909C), Color(0xFF546E7A), Color(0xFF90A4AE)),
  rose(Color(0xFFF43F5E), Color(0xFFE11D48), Color(0xFFFB7185));

  const FolderColor(this.primary, this.shadow, this.highlight);

  final Color primary;
  final Color shadow;
  final Color highlight;

  String get label => name[0].toUpperCase() + name.substring(1);

  static FolderColor fromName(String name) =>
      FolderColor.values.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
        orElse: () => FolderColor.blue,
      );
}
