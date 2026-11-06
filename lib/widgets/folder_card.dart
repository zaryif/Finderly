import 'package:flutter/material.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/widgets/folder_icon.dart';

class FolderCard extends StatelessWidget {
  final FolderModel folder;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onChangeColor;
  final VoidCallback? onMerge;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback? onSelectToggle;

  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    this.onRename,
    this.onChangeColor,
    this.onMerge,
    this.onMove,
    this.onDelete,
    this.isSelecting = false,
    this.isSelected = false,
    this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isSelecting ? onSelectToggle : onTap,
      onLongPress: () {
        if (isSelecting) {
          onSelectToggle?.call();
        } else if (onSelectToggle != null) {
          onSelectToggle!();
        } else {
          _showContextMenu(context);
        }
      },
      borderRadius: BorderRadius.circular(12),
      hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade400, width: 1.5),
              )
            : null,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FolderIcon(color: folder.color, size: 64),
                const SizedBox(height: 6),
                Text(
                  folder.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (isSelecting)
              Positioned(
                top: 0,
                right: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onMove != null)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined, color: Colors.blue),
                title: const Text('Move to Folder...'),
                onTap: () {
                  Navigator.pop(context);
                  onMove!();
                },
              ),
            if (onRename != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  onRename!();
                },
              ),
            if (onChangeColor != null)
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Change Color'),
                onTap: () {
                  Navigator.pop(context);
                  onChangeColor!();
                },
              ),
            if (onMerge != null)
              ListTile(
                leading: const Icon(Icons.merge_type),
                title: const Text('Merge into Folder...'),
                onTap: () {
                  Navigator.pop(context);
                  onMerge!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
