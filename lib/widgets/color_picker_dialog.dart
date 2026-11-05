import 'package:flutter/material.dart';
import 'package:finderly/theme/folder_colors.dart';

class ColorPickerDialog extends StatelessWidget {
  final FolderColor? selected;

  const ColorPickerDialog({super.key, this.selected});

  static Future<FolderColor?> show(BuildContext context, {FolderColor? current}) {
    return showDialog<FolderColor>(
      context: context,
      builder: (_) => ColorPickerDialog(selected: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Color'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: FolderColor.values.map((color) {
          final isSelected = color == selected;
          return InkWell(
            onTap: () => Navigator.pop(context, color),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.primary,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 22)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

